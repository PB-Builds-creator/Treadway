// Cairn — "send-reminders" Supabase Edge Function.
// Invoked every 5 minutes by pg_cron. Computes the current Mountain-Time moment,
// finds each user's tasks that are due, timed, still-incomplete, and just reached
// their time, plus an optional nightly "unfinished" summary — and sends a web push
// to that user's devices. A reminder_log row de-dupes so nothing sends twice a day.
//
// Deploy this as an Edge Function named exactly: send-reminders  (Verify JWT = OFF).
// Secrets it needs: VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT, CRON_SECRET.
// (SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided automatically.)

import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const TZ = "America/Denver";
const WINDOW_MIN = 15; // fire a reminder whose time landed within the last 15 minutes

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC = Deno.env.get("VAPID_PUBLIC")!;
const VAPID_PRIVATE = Deno.env.get("VAPID_PRIVATE")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.com";
const CRON_SECRET = Deno.env.get("CRON_SECRET")!;

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC, VAPID_PRIVATE);

function denver(now: Date) {
  const p: Record<string, string> = {};
  for (const x of new Intl.DateTimeFormat("en-US", {
    timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: false, weekday: "short",
  }).formatToParts(now)) p[x.type] = x.value;
  const wd: Record<string, number> = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 };
  const hour = p.hour === "24" ? 0 : parseInt(p.hour, 10);
  return { ymd: `${p.year}-${p.month}-${p.day}`, minutes: hour * 60 + parseInt(p.minute, 10), weekday: wd[p.weekday] };
}
function occurs(rule: any, weekday: number): boolean {
  if (!rule || rule.type === "daily") return true;
  if (rule.type === "weekdays") return (rule.days || []).includes(weekday);
  if (rule.type === "weekly") return rule.day === weekday;
  return true;
}
function timeToMin(t: string | null): number | null {
  if (!t) return null;
  const [h, m] = t.split(":").map(Number);
  return h * 60 + m;
}
function inQuiet(minutes: number, qs: string | null, qe: string | null): boolean {
  const s = timeToMin(qs), e = timeToMin(qe);
  if (s === null || e === null) return false;
  return s <= e ? (minutes >= s && minutes < e) : (minutes >= s || minutes < e); // overnight wrap
}

Deno.serve(async (req) => {
  if (req.headers.get("x-cron-secret") !== CRON_SECRET) return new Response("forbidden", { status: 403 });

  const sb = createClient(SUPABASE_URL, SERVICE_KEY);
  const { ymd, minutes, weekday } = denver(new Date());

  const { data: settings } = await sb.from("reminder_settings").select("user_id,enabled,summary_time,quiet_start,quiet_end").eq("enabled", true);
  let sent = 0;

  for (const s of settings ?? []) {
    const uid = s.user_id;
    const { data: subs } = await sb.from("push_subscriptions").select("*").eq("user_id", uid);
    if (!subs || subs.length === 0) continue;

    const { data: tasks } = await sb.from("tasks").select("*").eq("user_id", uid).eq("archived", false);
    const { data: comps } = await sb.from("completions").select("task_id,status").eq("user_id", uid).eq("day", ymd);
    const done = new Set((comps ?? []).filter((c) => c.status === "done").map((c) => c.task_id));
    const due = (tasks ?? []).filter((t) => occurs(t.rule, weekday));

    const toSend: { kind: string; title: string; body: string }[] = [];

    const quiet = inQuiet(minutes, s.quiet_start, s.quiet_end);
    for (const t of due) {
      const tmin = timeToMin(t.time);
      if (tmin === null || done.has(t.id)) continue;
      if (t.remind === false) continue;            // per-task reminder turned off
      if (quiet) continue;                          // inside quiet hours
      const delta = minutes - tmin;
      if (delta >= 0 && delta < WINDOW_MIN) toSend.push({ kind: `task:${t.id}`, title: "Cairn", body: `⏰ ${t.title}` });
    }
    const smin = timeToMin(s.summary_time || "21:30");
    if (smin !== null) {
      const d = minutes - smin;
      if (d >= 0 && d < WINDOW_MIN) {
        const remaining = due.filter((t) => !done.has(t.id)).length;
        if (remaining > 0) toSend.push({ kind: "summary", title: "Before bed", body: `You have ${remaining} thing${remaining === 1 ? "" : "s"} still open today.` });
      }
    }

    for (const n of toSend) {
      // Insert the log first; a unique-violation means it already went out today.
      const { error: logErr } = await sb.from("reminder_log").insert({ user_id: uid, kind: n.kind, day: ymd });
      if (logErr) continue;
      for (const sub of subs) {
        try {
          await webpush.sendNotification(
            { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
            JSON.stringify({ title: n.title, body: n.body, tag: n.kind }),
          );
          sent++;
        } catch (err: any) {
          if (err?.statusCode === 404 || err?.statusCode === 410) {
            await sb.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
          }
        }
      }
    }
  }

  return new Response(JSON.stringify({ ok: true, ymd, minutes, sent }), { headers: { "Content-Type": "application/json" } });
});

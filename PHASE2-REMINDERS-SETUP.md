# Phase 2 — turn on scheduled reminders (one-time, your account only)

This is set up **once**. It then sends reminders to **both** of you automatically —
her phone just needs the in-app Reminders toggle (see `Web/setup.html`), never any
of this.

Do the steps in order. Everything you paste is in this folder.

---

## 1. Make sure the reminder tables exist
If you haven't already: Supabase → **SQL Editor** → New query → paste all of
`reminders-schema.sql` → **Run**.

## 2. Deploy the function
Supabase → **Edge Functions** (left sidebar) → **Deploy a new function** /
**Create function**:
- **Name it exactly:** `send-reminders`
- Paste the entire contents of **`supabase-send-reminders.ts`** into the editor.
- **Turn OFF "Verify JWT"** (a toggle on the deploy screen, or in the function's
  settings afterward). The function protects itself with a secret instead.
- **Deploy.**

_(No dashboard editor in your project? Use the CLI instead — see "CLI fallback" below.)_

## 3. Set the function's secrets
Edge Functions → **Secrets** (or Project Settings → Edge Functions → Secrets) →
add these four (copy the values from `vapid-private-KEEP-SECRET.txt`):

| Name | Value |
|------|-------|
| `VAPID_PUBLIC`  | `BNEvMGCClT1cH8lUSzGvy8VgxI5doasaqB23hpYyXKsNK_hwMqMh7GJqVvDuuRHkuHrZRj6SlgoB0bbHCY0RCpw` |
| `VAPID_PRIVATE` | `Alro-mfxXjYJw-7uexP5PWzxDpt25qg9PZwKnShx478` |
| `VAPID_SUBJECT` | `mailto:paxtonraithel@gmail.com` |
| `CRON_SECRET`   | `a83391ff4fce91e1526a26f6adfa8d1acc21d1c2941f7836` |

(`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically — don't add them.)

## 4. Schedule it
SQL Editor → New query → paste all of `cron-schedule.sql` → **Run**. This makes it
run every 5 minutes. Check with `select * from cron.job;`.

## 5. Tell me
Say "done" and I'll trigger a test run against your live function and confirm it
returns OK (and, if a task is due, that a push actually lands on your phone).

---

## CLI fallback (only if the dashboard can't create functions)
```bash
brew install supabase/tap/supabase
supabase login                      # opens browser, one click
supabase link --project-ref bckcawaiyybrjsphiqdc
mkdir -p supabase/functions/send-reminders
cp supabase-send-reminders.ts supabase/functions/send-reminders/index.ts
supabase functions deploy send-reminders --no-verify-jwt
supabase secrets set \
  VAPID_PUBLIC=BNEvMGCClT1cH8lUSzGvy8VgxI5doasaqB23hpYyXKsNK_hwMqMh7GJqVvDuuRHkuHrZRj6SlgoB0bbHCY0RCpw \
  VAPID_PRIVATE=Alro-mfxXjYJw-7uexP5PWzxDpt25qg9PZwKnShx478 \
  VAPID_SUBJECT=mailto:paxtonraithel@gmail.com \
  CRON_SECRET=a83391ff4fce91e1526a26f6adfa8d1acc21d1c2941f7836
```
Then do step 4 above.

## How the reminders behave
- A task with a **time** set nudges you at that time **only if it's still unchecked**.
- A **nightly summary** (~9:30 PM Mountain, adjustable) says how many things are still open.
- Never sends the same reminder twice a day; never sends for completed tasks.
- To pause everything: `select cron.unschedule('cairn-reminders');`

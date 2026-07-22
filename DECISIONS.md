# Cairn — Key Decisions

_Last updated: 2026-07-22. Brief rationale for choices that aren't obvious from the code._

- **Web app is the primary product, not native.** Native needs $99 Apple Developer for the
  features that matter (widgets, Health) and per-device install friction; the web PWA gives
  sync + logins + reminders + home-screen install for free. Native is a "later" path.

- **No framework / no build step for the web app.** One `app.js` served statically. Keeps the
  project trivially deployable (Surge drag/CLI), easy to reason about, zero toolchain rot. Cost:
  a large single file and manual DOM rebuilds — accepted for a personal-scale app.

- **Optimistic local `state` + fire-and-forget sync + offline outbox.** UI updates instantly
  from an in-memory `state` mirrored to localStorage; writes push to Supabase in the background
  and queue on failure. Gives an app-like feel and offline use without a sync framework.

- **Supabase + Row-Level Security as the whole backend.** Each table is user-scoped by RLS, so
  the publishable/anon key is safe in client code. Cross-user access is deliberate and narrow:
  partner-share (daily_status/profiles partner_read policies) and admin (`is_admin()` SECURITY
  DEFINER fn). Chosen over a custom server for zero-ops + free tier.

- **America/Denver is the single source of truth for all dates.** All day math goes through
  `Intl.DateTimeFormat`/UTC helpers, never raw `Date` arithmetic — correct across DST and device
  timezones. This logic is the most-tested part (headless eval tests).

- **Reminders = pg_cron → Edge Function → web-push, deduped by a log table.** Browsers can't
  schedule notifications while closed, so a server sends them. `reminder_log(user,kind,day)`
  unique constraint prevents duplicate sends. `send-reminders` runs every 5 min, fires within a
  15-min window, honors per-task `remind`, quiet hours, and `summary_time`.

- **PIN lock is a per-device convenience, not the security boundary.** Real security = account
  (email+password) + RLS + disabled/ gated signups. PIN (localStorage per device) just gates an
  already-signed-in device; re-locks after 60s backgrounded. Codes never shown in UI.

- **Streak model favors "don't punish humans."** A day "succeeds" if ALL tasks done OR all
  non-negotiables (`keystone`) done. Rest days + saved days are neutral (skip). Streak-save is
  stingy: once per calendar month AND only offered when it would actually extend the streak.

- **Access hub gate fails OPEN** (loadAccess error → approved) so the owner is never locked out
  by a transient error; the trade-off (a pending user could slip through on error) is fine at
  friends scale. Self-approval blocked by the insert RLS policy (pending + is_admin=false only).

- **Themes: accent syncs (identity), light/dark/oled is device-local (preference).** Accent
  lives in the profile; theme in localStorage.

- **Handoff files (this + PROJECT_CONTEXT/TODO/CHANGELOG) are maintained every significant
  change** because sessions have low context limits and may hand off at any time.

- **Motion is transform/opacity-only and survives full DOM replacement in JS.** Launch and tour
  overlays sit outside `#app`; anything that crosses `render()` keeps its state in globals. The
  cold launch is skippable, runs only when the script boots, and self-dismisses below 900ms so it
  never gates data loading or interaction. Reduced-motion bypasses JS motion entirely.
  Spotlight geometry is assigned once per step, then travels through a FLIP-style transform;
  the drag shadow is a static shadow layer whose transform/opacity sells the rise.

- **Direct-manipulation gestures paint once per display frame.** Pointer events can arrive faster
  than the screen refreshes, so swipe and drag handlers only retain the newest coordinates and a
  single `requestAnimationFrame` performs compositor-friendly transforms. Gesture-only
  `will-change` avoids keeping every task row promoted while idle.

- **Navigation has restrained spatial logic.** Today → Week → History → Settings moves left;
  the reverse moves right, and the tab indicator travels from its remembered prior index. Task
  completion leads the row FLIP, then the ring follows, so the two effects read as cause/effect.

- **Today reads top-down as context → state → action → reflection.** The previous independent
  date, progress, streak, rest, and hydration widgets made the top feel scattered. They now share
  one hierarchy inside a "day stone"; task groups form a continuous path beneath it, and the
  existing synced note becomes the closing journal ritual. No behavioral or data-model changes.

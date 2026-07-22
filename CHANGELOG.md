# Cairn — Changelog

_Concise milestone log, newest first. Keep to meaningful milestones._

## 2026-07-22
- **Order is yours now (root cause of "drag doesn't stick"):** Today sorted rows by `byTime`,
  which re-sorted right after every reorder. Now sorts by `sort_index` (`bySort`) — time is
  purely a reminder and never affects position. Verified: a 6am task stays last if you put it last.
- **Drag between categories:** dropping a task on another group's card re-homes it to that
  category (`dropTask`; cards carry `data-group`; drop target resolved via `elementFromPoint`
  with the dragged row temporarily excluded from hit-testing). Verified: anytime → bed moved the
  task and re-indexed both groups. Removed a `lostpointercapture` handler that could end a drag
  prematurely.
- **Reminder toggle surfaced:** "Remind me at this time" now sits directly under the (renamed)
  "Reminder time" field instead of inside More options, with a note that time never affects order.
- **Touch drag fix:** added a non-passive `touchmove` blocker on rows that `preventDefault()`s
  while a swipe/drag is active. Root cause: `touch-action:pan-y` let mobile Safari start scrolling
  on the first vertical finger move, firing `pointercancel` and killing the drag. Because the
  finger is stationary through the 420ms long-press, that first touchmove is still cancelable, so
  blocking it stops the scroll ever starting. (Mouse path re-verified: 3rd task → top = c,a,b.)
  STILL NEEDS REAL-DEVICE CONFIRMATION — no touch device available in dev.
- **Drag no longer highlights text:** `#app` is `user-select:none` + `-webkit-touch-callout:none`
  (inputs/textareas re-enabled as selectable), plus `body.dragging-row` hard-disables selection
  during a drag, selection is cleared on drag start, and `contextmenu`/`selectstart` are
  suppressed on rows — kills the iOS long-press highlight + callout menu.
- **Sheet fixes:** sheets no longer scroll the page behind them (`overscroll-behavior:contain`,
  `body.sheet-open .scroll{overflow:hidden}`, `touch-action` on bg/sheet), and the notch is now a
  real drag handle — 66×28 hit area, follows your finger, backdrop fades with the drag, releases
  past 90px to dismiss (else springs back). Sheets close with a slide-down instead of vanishing.
- **FLIP completion animation:** checking a task now glides it from its original row down into
  Completed while the remaining rows slide up to close the gap (`captureRows`/`playFlip`,
  .44s eased). No more teleporting. Verified: 3 rows animated, e.g. translate(0, 72.75px).
- **Row gestures (no SQL):** each task row is now a `.rowwrap` with action layers behind it.
  **Swipe right → blue pencil (edit)**, **swipe left → red trash (delete w/ undo)**; icons scale
  in and "arm" past the 78px threshold, row springs back otherwise. **Press-and-hold → drag to
  reorder** (Apple-style): 420ms long-press elevates the row (scale+shadow+haptic), neighbours
  slide to open a gap, drop commits and re-flows global `sort_index` (`bindRowGestures`,
  `commitReorder`). Click is suppressed after a gesture so it never toggles by accident.
  Two tour steps added ("Swipe a task", "Hold to rearrange"). Verified in-browser (swipe reveal +
  reorder a,b,c→b,c,a). NOTE: touch-scroll-vs-drag on a real iPhone still needs device testing.
- **Motion & polish pass (CSS-only, honors `prefers-reduced-motion`):** page content fades/rises
  in on tab change (`.scroll.enter`, gated by `lastRenderedTab` so it doesn't animate on every
  tap); unified press/hover micro-interactions on buttons/rows/setrows/chips/tabs (active scale,
  tab-icon spring, row press bg, desktop hovers). **Tutorial upgraded:** caption-only steps now
  sit over a **blurred+dimmed backdrop** (`.tourbackdrop`) so the Cairn welcome/final cards are
  readable (spotlight steps stay crisp); caption re-animates in each step (`.tourcap.pop`);
  tour buttons get press states. Verified in-browser.
- **Polish pass (no SQL — `archived`/`sort_index` columns already existed):**
  - Fixed the scroll-jump: `render()` now preserves `.scroll` position on same-tab re-renders
    (resets only on tab change) via `lastRenderedTab`.
  - **Manage tasks** reworked: reorder with ↑/↓ (`mMove`), **Archive/Restore** (`mArchive`, active
    + Archived sections), **Duplicate** (`mDuplicate`). Delete now has a 4.5s **Undo** toast
    (`mDeleteWithUndo` + `showToast`; server delete deferred until the toast clears).
  - Editor: advanced fields (open-app, track-number, water/keystone/remind) collapsed under
    **"More options"** (auto-expands when editing a task that already uses them).
  - Empty Today points at **＋** and offers one-tap starter chips (`emptyToday`, `quickAdd`).
  - Tour: added **Accent color** + **Background & theme** steps; the "Add to Home Screen" step is
    now folded into the tour (non-standalone only) instead of a separate interstitial; Manage
    caption mentions reorder/archive. Verified in-browser.
- **Signup asks for name** (name field on the request-access form) → used as the profile name
  instead of "Me" (stored `cairn_name_<userId>`, applied in `renderOnboard`).
- **Tour now auto-runs once for ANY member who hasn't seen it** (not just new signups), and
  gained two end steps spotlighting **Accent color** and **Background & theme**. 11 steps total.
- **Settings → "See the tutorial again"** (renamed from "How Cairn works") replays the tour.

## 2026-07-21
- **New-member onboarding:** removed the routine picker AND `presetYou`/`presetHer` from source
  (no one else's routine is seeded or even readable in the JS). New users get a **blank page**.
  Quick-add **＋** on the Today top bar.
- **Spotlight product tour** (`runTour`): a 9-step coach-mark walkthrough that DRIVES the real app —
  auto-switches tabs, scrolls, and dims everything except the element it's teaching (white ring +
  caption, Skip/Back/Next). Runs once for new users after onboarding; replay via Settings → "How
  Cairn works". Verified in-browser. Overlay is `.tourwrap`/`.tourspot`/`.tourcap`.
- **Rule: max 3 rest days per week** (Sun–Sat) enforced in `toggleRestDay`.
- **Onboarding polish:** first-run PIN code is now **optional/skippable** ("Skip — open without
  a code"); a one-time "Add to Home Screen" (Safari) tip shows after setup for non-installed
  users. New flow in `showApp()`: PIN-if-set → first-run set/skip → home-screen tip → app.
  Background re-lock only applies if a code is set.
- **Access hub / admin gate** (code live; user must run `access-hub.sql` + re-enable signups):
  owner-only Members screen to approve/deny requests; new users land "pending"; owner + gf
  auto-approved. RLS + `is_admin()` fn. Re-added "Request access" signup.
- **Appearance & polish:** pure-black OLED theme (`data-theme="oled"`); Appearance picker
  (System/Light/Dark/OLED) persisted; auto-hiding bottom tab bar on scroll; accent palette
  expanded to 12 (added graphite/rose/ocean/olive/mauve/ember).
- **Tier 2 complete:** deep-link "open app" per task; monthly streak-save; weekly-review card;
  JSON export/backup; all-time totals; backfill past days (Week); non-negotiables (keystone);
  notes/journal; log-real-numbers (measured tasks + History Trends bars); reminder tuning
  (nightly-summary time, per-task remind toggle, quiet hours — `send-reminders` redeployed);
  overdue surfacing. SQL: `grace-and-couple.sql`, `tasks-appurl-and-savestreak.sql`, `tier2-all.sql`.
- **Grace:** rest days that protect streaks (verified 6/6 headless).
- **Couple layer (MVP, untested pending her phone):** pairing via 6-digit code + `link_partner`
  RPC; shared daily-status card ("finished their day"/"X of Y"). Nudge NOT built.
- **Reminders (Phase 1+2) live & verified:** web-push subscription + `send-reminders` edge fn +
  pg_cron every 5 min. Sent real pushes (verified `sent:2`). VAPID keys in KEEP-SECRET file.
- **iOS overscroll fix:** root painted with theme bg (no white bezels); `100dvh`.

## 2026-07-20
- **Web app built & deployed** to https://cairn.surge.sh (Surge). Vanilla JS + Supabase, RLS,
  offline cache, PWA, per-device PIN lock, seeded routines (owner's + girlfriend's 140oz/gym/
  cats/meals/sleep). Codes set to 0930 / 0307. Signups disabled (later reopened via hub).
- **Interactive preview** published as a Claude Artifact (localStorage-only) before the real app.
- **Native app:** CairnCore Swift package (Foundation-only logic: recurrence, Mountain-Time/DST,
  hydration, streaks, notification planner, sync merge, seed, JSON archive) — 57/57 tests pass.
  Full SwiftUI app + widgets + App Intents authored; macOS free/local build (`project.mac.yml`)
  compiles, installs to `/Applications/Cairn.app`, runs (seeded 7 tasks). Xcode 26.6 installed.

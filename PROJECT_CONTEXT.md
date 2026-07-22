# Cairn — Project Context

_Handoff doc. Read this + TODO.md + DECISIONS.md + CHANGELOG.md, then the code._
_Last updated: 2026-07-22._

## LATEST RELEASE — three web-first product lanes (activated in production)
The user explicitly asked to build three sellability upgrades together while postponing all
native/widget/HealthKit work until they buy the Apple Developer account. The clean checkpoint
before this pass is `4d6d367` (`Smooth row gestures`); implementation checkpoints are `5923dbd`
and `e92bdc9`, with reviewed release code at `ff7736d`.

Implemented and visually QA'd at 375×812 in Light/OLED:
- Cairn Close with a win, honest line, tomorrow's first stone, yesterday carry-forward, legacy
  reflection compatibility, a single structured upsert, local preservation/retry before the
  optional column exists, and one-shot seal motion.
- Rolling Weekly Trail with seven-day rhythm, closes, water goals, memories, next foothold, and an
  explicit note that task edits reshape this current-path view.
- Fixed once-daily mutual-partner Proud nudge, explicit confirmation, no offline queue, reciprocal
  unlink, quiet-hour delivery, and server checks that reveal no tasks/progress/journal content.
- Hardened approval/RLS, narrow partner-profile RPC, signup-name preservation, password recovery
  and change, full JSON export, password-reauthenticated account deletion (also available to
  pending/denied users), formal public privacy policy, and cache/outbox cleanup on every
  sign-out path.
- Canonical product SQL in `cairn-product-upgrade.sql`; obsolete `access-hub.sql` and top-level
  reminder function are inert pointers. Tracked setup docs contain placeholders, not credentials.

Independent reviews found and the release fixes: the first-Close insert/update race, false Close
sync before migration, repeated seal animation, legacy notes counted as closed, arbitrary couple
probing, whole-profile partner reads, rerun auto-approval, relink overwrite, broad nudge grants,
false delivery on reminder-log errors, pending-user deletion gap, and categorical network-failure
claims. `send-reminders` and authenticated `delete-account` are deployed; unauthorized probes
correctly return 403 and 401. On July 22, 2026, `cairn-product-upgrade.sql` was applied to the live
project, the historically tracked VAPID pair and CRON_SECRET were rotated together, all four Edge
secrets were updated, the five-minute cron job was recreated with the new secret, and a direct
function probe returned `ok:true`. Supabase Auth was confirmed to allow signups, require email
confirmation, and use `https://cairn.surge.sh` as both Site URL and redirect. A disposable-account
live suite confirmed the real owner is an approved admin, pending users cannot write app data,
owner-policy approval works, links are reciprocal, Proud nudges dedupe once daily, full partner
profiles stay private, and unlink removes access from both sides; all test users/rows were then
deleted. The activation web deploy published the rotated public key, formal privacy policy, and
shell-cache bump; production copies of app.js, config.js, privacy.html, styles.css, and sw.js
matched local byte-for-byte, and the live policy had the formal heading with no early-access
language. The remaining operational step is iPhone reminder resubscription and later two-device
push/feel QA listed in TODO.md. A final read-only check found the real owner currently has no
partner link. The girlfriend's account identifier is deliberately not documented, and there are
multiple approved members, so no agent should guess; pair the two real PWAs with the six-digit
code when her phone is available.

## What this is
A private daily-discipline / checklist app for Paxton (owner) + his girlfriend, on a
personal-use basis (now with an owner-gated hub so friends can request access).

There are **two deliverables**:
1. **Web app (`Cairn/Web/`) — THE ACTIVE PRODUCT.** Live at **https://cairn.surge.sh**.
   This is the daily driver and where all current work happens.
2. **Native SwiftUI app (`Cairn/App`, `Cairn/CairnCore`) — parked.** Builds & runs on
   Mac (Xcode 26.6). Free/local config `project.mac.yml`. Native (widgets, Apple Health,
   Face ID) is the "$99 Apple Developer, in a few months" path. Not being worked on now.

## Web app — architecture
- **No framework, no build step.** Plain static files served by Surge.
  - `Web/index.html` — shell; loads Supabase UMD from CDN, `config.js`, `styles.css`, `app.js`; registers `sw.js`.
  - `Web/app.js` — the ENTIRE app (~1550 lines, vanilla JS). State + logic + all screens.
  - `Web/styles.css` — design system via CSS custom properties (tokens).
  - `Web/config.js` — Supabase URL + publishable key + VAPID public key (all safe to expose).
  - `Web/sw.js` — service worker: network-first shell cache + web-push handlers.
  - `Web/manifest.webmanifest`, `Web/icon-*.png`, `Web/icon.svg` — PWA.
  - `Web/setup.html` — hosted "set up a new phone" guide (cairn.surge.sh/setup.html).
- **Backend: Supabase** (Postgres + Auth + RLS + Edge Functions + pg_cron).
  - Project ref: `bckcawaiyybrjsphiqdc` · URL `https://bckcawaiyybrjsphiqdc.supabase.co`.
  - Row-Level Security everywhere: each user sees only their own rows. Partner-share and
    admin are the only cross-user reads (via policies / SECURITY DEFINER fns).
  - Edge Function `send-reminders` (Deno, `Cairn/supabase/functions/send-reminders/index.ts`)
    runs every 5 min via pg_cron → sends web-push reminders.

### app.js structure (how it works)
- Global `state` = the signed-in user's data `{name,accent,goalOz,tasks,completions,
  hydration,restDays,savedDays,notes,values,summaryTime,quietStart,quietEnd,partnerId,
  partnerName,partnerStatus,totals}`. Also globals: `access`, `unlocked`, `session`, `userId`.
- **Render**: template strings → `root.innerHTML` → `bindApp()` re-attaches `data-act`/`data-tab`
  click handlers (event delegation). `render()` rebuilds everything each call.
- **Mutations** (`mSetStatus`, `mAddWater`, `mUpsertTask`, `mSetValue`, `mSaveProfile`, …):
  update `state` + localStorage cache instantly → `render()` → fire-and-forget `push()` to
  Supabase (queues to `outbox` on failure; flushes on reconnect). Optimistic + offline-first.
- **All dates** go through America/Denver `Intl` helpers (`todayStr`, `addDays`, `weekdayOf`,
  `denverParts`). Never use raw `Date` day math.
- **Auth gate order**: session? → `loadAccess` (approval gate) → `showApp()` gate. `showApp()`:
  PIN enter (if a code is set) → first-run set-code-OR-skip (`renderLockSetup(true)`, optional) →
  one-time Home-Screen tip (Safari, only if `!isStandalone()`) → onboarding (if no profile) → app.
  Lock code + skip/tip flags are per-device localStorage (`cairn_lock_*`, `cairn_lockskip_*`,
  `cairn_hometip_*`, keyed by userId).
- **Themes**: `data-theme` on `<html>` = system|light|dark|oled; tokens in styles.css; accent
  set via JS `setProperty(--accent…)`. Theme persists in localStorage (`cairn_theme`), accent
  syncs via profile.

## Deploy / ops (all runnable headlessly from this Mac — logins cached)
- **Web deploy:** `cd /Users/paxton/Cairn/Web && npx surge . cairn.surge.sh`
- **Edge fn deploy:** `cd /Users/paxton/Cairn && supabase functions deploy send-reminders --project-ref bckcawaiyybrjsphiqdc --no-verify-jwt --use-api`
- **Trigger reminder fn (test):** `curl -X POST https://bckcawaiyybrjsphiqdc.supabase.co/functions/v1/send-reminders -H "x-cron-secret: <CRON_SECRET>"` → `{"ok":true,...,"sent":N}`
- **Secrets (NOT in Web/, never deploy):** `Cairn/vapid-private-KEEP-SECRET.txt` (VAPID public/private, CRON_SECRET). Gitignored via `*KEEP-SECRET*` — keep it that way.
- **Version control:** local git repo (no remote). Baseline commit `9f7f24b`, 2026-07-22.
  Commit before risky edits; `git diff`/`git checkout -- <file>` is the rollback path for
  `Web/app.js`. Ignored: `.build/` (113M), `Cairn.xcodeproj/` (XcodeGen output), secrets, `.DS_Store`.
- **SQL migrations** live in `Cairn/*.sql`. `cairn-product-upgrade.sql` is already active in the
  live project. `access-hub.sql` is retired and must not be run. `cron-schedule.sql` must retain
  its literal `<CRON_SECRET>` placeholder in git; substitute the real value only in a temporary
  copy or Supabase SQL Editor.

## Testing
- `node --check Web/app.js` for syntax.
- Pure logic tested headlessly: read app.js, stub browser globals (window/document/navigator/
  localStorage/Notification), strip the trailing boot guard, `eval(src + tests)`. See git history
  / prior `/tmp/test_*.js`. Streak/grace/keystone logic all verified this way.
- **Visual QA:** use a temporary local static server and a small Supabase stub in `/tmp` to inject
  representative signed-in state; never commit the fixture. The current pass covered Today,
  unsealed/sealed/legacy Close, Close editor, Trail, Settings/privacy, auth, onboarding, long
  hostile-looking text, missing-`close_data` fallback, Light, and OLED at 375×812 without browser
  logs or horizontal overflow. Live shell/hash verification still follows deployment.
- Real device feel (gestures, iOS push, PWA) still needs the user.

## Row gestures & ordering (recent, non-obvious)
- **Order = `sort_index` only.** `bySort` drives Today's lists. A task's `time` is a REMINDER
  ONLY and must never be used as a sort key (that bug made drag-reorder appear not to save).
- **`rowHtml` renders `.rowwrap` > (`.rowacts` + `.row`).** `.rowwrap` carries `data-rid`;
  group cards carry `data-group`. Dividers/radii live on `.rowwrap`, not `.row`.
- **`bindRowGestures()`** (called from `bindApp`) handles per-row pointer gestures:
  horizontal ≥10px → swipe (right = edit, left = delete, 78px commit threshold);
  420ms stationary hold → drag reorder (elevate + neighbours shift). `suppressClick` blocks the
  toggle after any gesture. A non-passive `touchmove` blocker prevents mobile Safari stealing the
  gesture as a scroll. Pointer moves only store the latest position; one `requestAnimationFrame`
  paints the swipe/drag via `translate3d`, and direction/armed classes change only across their
  thresholds. Do not put per-event DOM writes back in this hot path. Do NOT re-add a
  `lostpointercapture` handler — it ends drags prematurely.
- **Drop resolution:** `endDrag` hides the dragged row from hit-testing, `elementFromPoint`s the
  drop, finds `.card[data-group]` → `dropTask(id, group, beforeId)` re-homes the task's category
  and re-flows all `sort_index`. Same-card drops fall back to `commitReorder`.
- **FLIP** (`captureRows`/`playFlip`) animates rows gliding between positions on complete/drop.
- **Motion state also lives outside rendered DOM:** the cold-launch overlay is appended to `body`
  while auth/data load behind it, and is capped below 900ms; the tour overlay likewise survives
  app re-renders so its spotlight can travel between targets. All JS motion exits through
  `prefersReduce()` and CSS is covered by the existing reduced-motion rule.
- **Completion motion is deliberately causal:** `mSetStatus` captures rows, renders the new
  state, starts FLIP, then lets the ring sweep follow 90ms later. Ring/streak/hydration previous
  values live in globals because their DOM nodes do not survive `render()`.
- **Today is organized as a single daily ritual:** `.daystone` owns date/status/progress/streak/
  water/rest hierarchy; `.pathsection` presents remaining tasks as one marked path; hydration is
  a compact daily rhythm and the synced note is elevated into a real reflection ritual. This is
  presentation only—task order, mutations, recurrence, streaks, and storage are unchanged.
- **The web shell is a real viewport-height flex chain:** `#app → #root → .screen → .scroll` all
  carry a constrained height/min-height, so `.scroll` (not the document) owns scrolling and the
  floating tabs remain at the phone edge. Do not remove `#root`'s flex/min-height rules.

## Rules (product)
- New members ALWAYS start with a blank task list, then a spotlight product tour (`runTour`) that drives the real app. No
  preset routines exist in code (owner/gf data lives only in their DB rows).
- Streak day "succeeds" if all tasks done OR all non-negotiables (`keystone`) done.
- Rest days: **max 3 per Sun–Sat week**. Streak-save: **1 per calendar month**, only when it
  would extend the streak. Rest + saved days are neutral in streak math.

## People / accounts
- 2 accounts: owner (Paxton, email `paxtonraithel@gmail.com`) + girlfriend. Owner = admin.
- PIN app-lock codes (per-device, localStorage, never shown): owner `0930`, gf `0307`.
- Her phone is NOT available for a few days. The live couple/RLS/RPC layer passed with disposable
  accounts, but her push subscription and the end-to-end two-phone notification remain untested.
- The owner currently has no live `partner_id`. The girlfriend's auth ID/email is not documented;
  do not infer it from the other approved members. Use the in-app pairing code on both real PWAs.

## Conventions
- Keep app.js dense but readable; match existing terse style. No new dependencies/build tools.
- Any new synced field: add column via a `*.sql` file, map in `rowToTask`/`taskToRow` or the
  relevant load/mutation fn, and hold the deploy until the user runs the SQL (writing a missing
  column breaks upserts).
- Verify streak/date logic with a headless eval test before deploying.
- Update these 4 handoff files after every significant change.

## Also see
User-level memory: `~/.claude/projects/-Users-paxton/memory/` (cairn-project.md,
cairn-feature-roadmap.md) — overlaps with these files; these repo files are authoritative for code.

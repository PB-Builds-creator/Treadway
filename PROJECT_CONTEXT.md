# Trailhead (formerly Cairn) — Project Context

_Handoff doc. Read this + TODO.md + DECISIONS.md + CHANGELOG.md, then the code._
_Last updated: 2026-07-22._

**Current handoff checkpoint:** repository source is at the deployed Trailhead identity release
(`e4eb0eb`) plus its production record (`b970c46`). The web app and `send-reminders` function are
live. No source or database work is pending from the rebrand; only the real-phone actions and
feel tests in TODO.md remain. Treat the latest-release section as current truth and the later
`PRIOR RELEASE` sections as historical implementation context.

## LATEST RELEASE — Trailhead identity system and PWA rebrand
The active customer-facing product is now **Trailhead**. A new code-native identity uses four
weathered trail stones crossed by one rising route. The same geometry now drives the realistic
installed icon, the sub-900ms cold launch, a prominent `Trailhead · Your daily path` lockup at the
top of Today, auth/lock/onboarding, the tutorial bookends and install demo, footer, setup guide,
privacy policy, export filename, service-worker fallback notifications, and Edge reminder titles.
The Today mark enters once per app session and gives a single light trail pulse after completion;
there is no new endless brand animation or gesture-time layout work.

The origin intentionally remains `https://cairn.surge.sh` so existing Supabase auth redirects,
sessions, and web-push origin assumptions do not migrate. Compatibility identifiers also remain:
`window.CAIRN_CONFIG`, `cairn_*` localStorage keys, SQL filenames, and the repository directory.
They are implementation details, not visible product copy. There is no SQL for this rebrand.
`https://trailhead.surge.sh` is already occupied by an unrelated site (its public document title
is `trailhead.app`); it is not owned by this project and must never be used in setup instructions
or as a deployment target. Until a deliberate origin migration is completed, every shared link
must use `https://cairn.surge.sh` even though the installed product name is Trailhead.
Existing iPhone Home Screen labels/icons are not remotely renamed; users must open the refreshed
site, delete the old Home Screen icon, and add it again as Trailhead. Account data remains in
Supabase and is not deleted by removing the shortcut.

Light and OLED Today, sign-in, the welcome tutorial cover, launch-to-header handoff, 375×812
horizontal containment, and browser logs passed local QA. `sw.js` shell v6 forces current assets.
The temporary signed-in fixture was deleted after QA. The release is live at
`https://cairn.surge.sh`; index, app, styles, service worker, manifest, 512 icon, privacy, and
setup files matched local byte-for-byte after deployment. The live 375×812 sign-in screen reports
Trailhead in the document, Apple PWA title, and UI with no browser warnings or horizontal
overflow. The `send-reminders` Edge Function was also redeployed so timed task pushes use the
Trailhead title.

**Commercial naming boundary:** Salesforce actively uses Trailhead/Trailhead GO. The user
explicitly chose Trailhead after being warned of that conflict, so it is implemented as the
user-directed working/private brand. It is not cleared for a paid public launch. Before charging
the general public, obtain a professional trademark clearance or choose a lower-conflict name.

## PRIOR RELEASE — professional tutorial aligned to the current UI
`runTour()` is now the current product walkthrough instead of the pre-redesign summary tour. It
preserves the original traveling spotlight, task gestures, rest/week/history/settings guidance,
Home Screen step, and stone-stack bookends while teaching the actual day stone, Trailhead Close,
Weekly Trail, account trust, partner boundary, and present Settings rows. A new account still
starts blank and automatically enters the tour after onboarding; Settings → See the tutorial
again replays the same sequence for established accounts.

The installed PWA has 14 steps; Safari/browser adds a fifteenth Home Screen step. Live targets
remain crisp inside a dimmed traveling exposure frame. Caption-only and blank-account steps use a
stronger blur plus a non-persistent animated showcase; the gesture showcase appears only when no
real `.rowwrap` exists and never creates or syncs sample data. The overlay freezes background
scroll, keeps captions inside the viewport, supports Back/Continue/Skip and keyboard arrows/Escape,
traps keyboard focus inside the dialog, restores Today on finish, marks first-run completion, and
honors reduced motion. A temporary local
Supabase fixture (removed after QA) verified automatic blank-account launch, every step through
the finale, the real-task spotlight fallback, and Settings replay. Real-iPhone feel remains in
TODO.md. `sw.js` shell v5 forces the updated app/CSS onto installed copies.
The release is live at `https://cairn.surge.sh`; production app.js, styles.css, and sw.js matched
local byte-for-byte after deployment, and the removed QA fixture returns 404 in production.

## PRIOR RELEASE — three web-first product lanes (activated in production)
The user explicitly asked to build three sellability upgrades together while postponing all
native/widget/HealthKit work until they buy the Apple Developer account. The clean checkpoint
before this pass is `4d6d367` (`Smooth row gestures`); implementation checkpoints are `5923dbd`
and `e92bdc9`, with reviewed release code at `ff7736d`.

Implemented and visually QA'd at 375×812 in Light/OLED:
- The close ritual (then named Cairn Close, now Trailhead Close) with a win, honest line,
  tomorrow's first stone, yesterday carry-forward, legacy
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
  - `Web/app.js` — the ENTIRE app (~1600 lines, vanilla JS). State + logic + all screens.
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
- **Never deploy to `trailhead.surge.sh`:** it belongs to an unrelated existing site. A future
  branded URL must be a different verified-available Surge subdomain or a purchased custom domain,
  followed by a planned Supabase Auth/PWA/push origin migration.
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
- **Visual QA:** use a temporary local static server and a small non-production fixture to inject
  representative signed-in state; remove it before committing or deploying. The current passes
  covered Today,
  unsealed/sealed/legacy Close, Close editor, Trail, Settings/privacy, auth, onboarding, long
  hostile-looking text, missing-`close_data` fallback, Light, and OLED at 375×812 without browser
  logs or horizontal overflow. The Trailhead release additionally verified the new sign-in,
  populated Today header, launch handoff, and tutorial cover; eight live assets then matched local
  byte-for-byte and the live phone-size sign-in view had no warnings or overflow.
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
  while auth/data load behind it, and is capped below 900ms. Its four-stone Trailhead mark draws
  the route once and, when Today is ready quickly, hands off to `.homebrandmark` rather than the
  progress ring. The tour overlay likewise survives
  app re-renders so its spotlight can travel between targets. Empty accounts use a tour-only
  gesture showcase rather than fake app data. All JS motion exits through `prefersReduce()` and
  CSS is covered by the existing reduced-motion rule.
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
- New members ALWAYS start with a blank task list, then the professional spotlight product tour
  (`runTour`) drives the real app. No preset routines exist in code (owner/gf data lives only in
  their DB rows); the animated gesture example is overlay-only and is never added to `state`.
- Streak day "succeeds" if all tasks done OR all non-negotiables (`keystone`) done.
- Rest days: **max 3 per Sun–Sat week**. Streak-save: **1 per calendar month**, only when it
  would extend the streak. Rest + saved days are neutral in streak math.

## People / accounts
- Core personal users are owner Paxton (`paxtonraithel@gmail.com`) and his girlfriend; the
  owner-gated hub can also contain other approved friends. Owner = admin. Do not assume an
  approved member is the girlfriend merely because multiple approved rows exist.
- PIN app-lock codes (per-device, localStorage, never shown): owner `0930`, gf `0307`.
- Her phone is rarely available. The live couple/RLS/RPC layer passed with disposable accounts,
  but her Trailhead reinstall, push resubscription, and end-to-end two-phone notification remain
  untested.
- The owner currently has no live `partner_id`. The girlfriend's auth ID/email is not documented;
  do not infer it from the other approved members. Use the in-app pairing code on both real PWAs.

## Conventions
- Keep app.js dense but readable; match existing terse style. No new dependencies/build tools.
- Any new synced field: add column via a `*.sql` file, map in `rowToTask`/`taskToRow` or the
  relevant load/mutation fn, and hold the deploy until the user runs the SQL (writing a missing
  column breaks upserts).
- Verify streak/date logic with a headless eval test before deploying.
- Update these 4 handoff files after every significant change: `PROJECT_CONTEXT.md` for current
  truth and architecture, `TODO.md` for only unfinished work, `DECISIONS.md` for durable rationale,
  and `CHANGELOG.md` for shipped milestones. State exactly what is live, local-only, manual,
  unverified, or superseded so a replacement agent never has to infer status from old entries.

## Also see
User-level memory: `~/.claude/projects/-Users-paxton/memory/` (cairn-project.md,
cairn-feature-roadmap.md) — overlaps with these files; these repo files are authoritative for code.

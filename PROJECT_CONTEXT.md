# Cairn — Project Context

_Handoff doc. Read this + TODO.md + DECISIONS.md + CHANGELOG.md, then the code._
_Last updated: 2026-07-22._

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
  - `Web/app.js` — the ENTIRE app (~1200 lines, vanilla JS). State + logic + all screens.
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
- **SQL migrations** live in `Cairn/*.sql`; run by the user in the Supabase SQL Editor. All run
  EXCEPT `access-hub.sql` (see TODO — user must run it + re-enable signups).

## Testing
- `node --check Web/app.js` for syntax.
- Pure logic tested headlessly: read app.js, stub browser globals (window/document/navigator/
  localStorage/Notification), strip the trailing boot guard, `eval(src + tests)`. See git history
  / prior `/tmp/test_*.js`. Streak/grace/keystone logic all verified this way.
- **Visual QA IS possible:** the in-app Browser tools work on the LIVE site. `preview_start`
  with `url:"https://cairn.surge.sh"`, then `javascript_tool` to inject a signed-in `state`
  (set globals `userId/session/access/unlocked/tab/state`, call `render()`), then `screenshot`.
  This is how the spotlight tour was verified. Can't log in (no creds) — inject state instead.
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
  gesture as a scroll. Do NOT re-add a `lostpointercapture` handler — it ends drags prematurely.
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

## Rules (product)
- New members ALWAYS start with a blank task list, then a spotlight product tour (`runTour`) that drives the real app. No
  preset routines exist in code (owner/gf data lives only in their DB rows).
- Streak day "succeeds" if all tasks done OR all non-negotiables (`keystone`) done.
- Rest days: **max 3 per Sun–Sat week**. Streak-save: **1 per calendar month**, only when it
  would extend the streak. Rest + saved days are neutral in streak math.

## People / accounts
- 2 accounts: owner (Paxton, email `paxtonraithel@gmail.com`) + girlfriend. Owner = admin.
- PIN app-lock codes (per-device, localStorage, never shown): owner `0930`, gf `0307`.
- Her phone is NOT available for a few days → couple-layer + her-device reminders untested.

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

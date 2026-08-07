# Treadway (formerly Trailhead, formerly Cairn) — Changelog

_Concise milestone log, newest first. Keep to meaningful milestones._

## 2026-08-06
- **Treadway Brief — explainable AI handoff.** Weekly Trail now ends with a locally generated,
  confidence-labeled brief whose observations expose their exact evidence and source. A versioned
  `treadway-weekly-coach-v1` contract prepares a constrained prompt for any user-selected AI chat;
  it forbids invented motives/diagnoses/events, requests one pattern + one seven-day experiment +
  one non-judgmental question, and caps the response. Nothing is transmitted automatically. Task
  titles and counts are visible in the reviewed copy payload; private Close text is excluded by
  default and enters only through a one-action checkbox. The pure browser/Node engine has no API,
  dependency, background CPU, database, or inference cost. Evaluation covers exact metrics,
  confidence, ranking, evidence provenance, determinism, immutability, privacy opt-in/out,
  grounding/prompt-injection instructions, bounded context, and malformed/low-evidence inputs. Dark/light card and evidence-sheet
  QA used synthetic data only; a portfolio screenshot and AI implementation case study document
  the feature. Shell cache advanced to v20.
- **Public portfolio readiness.** Repositioned the repository around the deployed Treadway PWA,
  separated the Cairn-named SwiftUI prototype as a native research track, and added synthetic-data
  product screenshots, a code-native banner, web architecture, an engineering case study, MIT license,
  security policy, contribution guide, Node verification, and GitHub Actions. Updated stale Treadway/
  deployment documentation and corrected a pre-existing optional-chaining compile error in one Swift
  test. Verification: web syntax/invariants and HTML validation pass; `swift test` executes 62 tests
  with zero failures; `cairncore-verify` reports 57/57; the macOS local-only Xcode target builds with
  signing disabled. Secret-pattern scans found no private credential in current tracked files or Git
  history; the ignored VAPID private-key file remains local-only.

## 2026-08-03
- **Visual + motion evolution (App-Store-grade, 4 phases, sw.js v17→v19).** User-approved evolution
  of the visuals (bolder color + real depth/materials) with weighted-quiet motion; identity/structure/
  copy preserved. Heuristic re-score **35 → 36/40 (Excellent band)**, detector clean throughout.
  - **P1 color+depth foundation:** `--accent` is now theme-aware and bold (light #43618a, dark #86a4c9,
    oled #8aa8cd) — also fixed accent-text failing WCAG AA on dark (3.2→6.4:1). Fills split into
    `--accent-fill #4a6890` + gradient `--accent-2 #35507a` (primary buttons); `--accent-soft` derives
    from `--accent`. New `--edge-hi` top-highlight + `--shadow-2` elevation.
  - **P2 material coherence:** the lit-from-above highlight now spans all cards (15+ surfaces); primary
    button press compresses its shadow (weighted).
  - **P3 Settings reorg:** flat 13-row list → 5 iOS grouped section cards (Your day/Appearance/Reminders/
    Account/Learn) with staggered entrance; all actions/IDs preserved.
  - **P4 verify:** OLED + light + sheet + grouped Settings all confirmed; reduced-motion covered by the
    blanket rule; 0 console errors; live parity. See DECISIONS "accent is theme-aware, fills split".
- **Impeccable-driven polish pass (critique → fixes → audit → re-critique).** Heuristic score
  **33 → 35/40** (upper "Good"), deterministic detector **3 findings → 0**, accessibility markedly up
  (role 0→2, tabindex 1→4, focus-visible rules 2→12). Refinement of the incumbent world, not a
  redesign. Fixes: **(P1 contrast)** `--faint` failed WCAG AA in all three themes (dark 3.2:1, oled
  2.8:1, light 2.8:1) — recomputed to clear 4.5:1 on real backgrounds (dark #8e908a, oled #828480,
  light #71736d); `--muted` was already fine. **(P2 hierarchy)** the `.daystats` stat row was a
  bordered card nested inside the day-stone card — dissolved into a borderless band with a top
  hairline so the ring is the single hero. **(P2 discoverability)** one-time swipe "peek"
  (`maybeSwipeHint`/`.peekhint`) nudges the first row to reveal the edit action; gated post-tour,
  max twice, reduced-motion-safe, canceled on pointerdown. **(a11y)** task rows are now
  `role=checkbox`/`button` + `aria-checked` + `aria-label` + `tabindex=0` with Enter/Space
  activation and `:focus-visible` rings — the primary action is keyboard/screen-reader accessible
  (edit/delete/reorder already had Manage-screen keyboard paths). **(P3 detector)** side-tab callout
  → tinted; tutorial dots off `transition:width` → transform; memory blockquote 2px→1px. Verified
  live at 375×812 in OLED + light: contrast legible, band dissolved, peek reveals, keyboard toggle
  works, 0 console errors. sw.js → v16. `impeccable` (design skill + detector hook) is installed in
  `~/.claude`.
- **Spinner removed + full-bleed icon.** The loading indicator is now the branded mark (breathing,
  way redraw) via `brandLoader()`; deleted `.spin`/`.loading`/`@keyframes sp` and the spinner in
  `enterApp`. With the pre-rendered launch, no spinner ever renders. The app icon is now full-bleed
  (bg fills the whole 1024 square; removed the 24px inset, self-rounding, and border that left
  white edges under iOS's squircle mask); regenerated `icon-180/192/512`. `sw.js` → v13. Users must
  remove + re-add the Home Screen icon to pick up the new art (iOS caches icons).
- **Flagship motion pass.** (1) **Launch = branded first paint:** the stepping-stones animation is
  now pre-rendered in `index.html` (with a no-flash theme script in `<head>`), so the very first
  frame is the mark laying itself in — the plain `.loading` spinner no longer shows on open
  (`.loading`/`.spin` CSS kept; still used behind the overlay during data load). `startLaunch`
  adopts the pre-rendered `#launch` and dismisses via a per-frame poll (min ~960ms so the mark
  fully lays in, cap 2.6s, tap-to-skip) that fires for ANY first screen — shared-element morph into
  the Today header when landing there, else a clean fade. Elevated visuals: radial glow, group
  rise, weightier nearest-first stone timing, drop shadow, longer way-draw. (2) **Page
  transitions:** richer directional slide + subtle scale + refined curve (.44s); active-tab icon
  springs (`tabpop`) on tab change only. (3) **Haptics:** central `haptic()` helper wired through
  every tab (tap) + button (light) in `bindApp`, plus semantic patterns (completion=success, drag
  pick/drop, cheat-day reward); replaces the old scattered `navigator.vibrate` calls. **iOS Safari
  ignores the Vibration API — Android-only; real iPhone haptics need the native app.** `sw.js` → v12.
  Ring odometer/milestones/celebrate were already present and untouched.
- **Crash safety / global error capture (sellability roadmap #5).** Added `window.error` +
  `unhandledrejection` handlers → `logError()`: captures to a bounded localStorage ring buffer
  (`cairn_errlog`, last 25, survives reload), best-effort inserts to a remote `error_log` table if
  present, and warns the user once (debounced 10s) with a "Reload" toast so a half-painted screen
  is never a silent mystery. The handler is fully wrapped so it can never throw or loop; the remote
  insert is fire-and-forget and silently ignored until the table exists — so the whole thing works
  with NO setup. Optional `error-log.sql` (new) creates the table with insert-own / admin-read RLS
  for a queryable server-side history. `sw.js` → v10. Verified live: both error kinds captured and
  classified, buffer caps at 25, toast fires once, signed-out skips remote, null-safe, zero console
  noise, no loop.
- **Mark cleanup + brand-moment follow-ups (post-rename).** `ICON.treadway` was still the OLD
  stacked geometry — the rename changed only the object key, so the lock-code screen, Today
  footer, auth, onboarding, and install demo all still showed the cairn. Made `ICON.treadway` a
  getter that returns `treadwayMarkHtml()`, so there is now ONE mark definition and it cannot drift
  again; retuned `.todayfoot` sizing to landscape. The Today top-left mark now **replays its
  entrance every time you arrive on Today** (app entry or tab switch), keyed off `lastRenderedTab`,
  but stays still on in-place re-renders (checking a task) — dropped the `brandHasEntered` global.
  Added a **one-time, per-device dismissible rebrand notice** on Today (`cairn_iconv2_<userId>`,
  `rebrandNoteHtml`/`dismissRebrand`) telling users to remove + re-add the Home Screen icon. The
  sign-in/unlock/onboarding mark now lays itself in (`.brandglyph` entrance). All under the
  existing reduced-motion guard. `sw.js` → v9. Verified live at 375×812: lock/top/footer marks all
  new; replay fires on entry + tab-return, not on re-render; notice shows once and dismiss persists.
- **Renamed Trailhead → Treadway and redesigned the mark.** Trailhead collided with Salesforce's
  active Trailhead/Trailhead GO brand; "Treadway" (the worn walking surface of a trail — the
  ground underfoot) was researched against software/app conflicts and came back clean, unlike
  Waystone / Whetstone / Cobble / Daystone / Esker, which were all taken. The identity changed
  metaphor with the name: the logo went from a **vertical cairn stack** to **four flat stepping
  stones rising along a path** with a worn way showing through the gaps. Redrew `icon.svg`,
  regenerated `icon-180/192/512.png` (qlmanage → sips; larger bytes, no PNG optimizer available
  but SW-cached so fetched once), and replaced the in-app `treadwayMarkHtml` (portrait 96×112 →
  landscape viewBox `-2 41 81 68`, way drawn first so it sits behind the stones). Retuned every
  place the mark is sized (auth, lock, launch, tour hero, home header, install demo) from portrait
  to landscape, and the launch stagger keyframe from a drop-in to a press-into-ground
  (`treadstonein`). All 88 "Trailhead" strings across app.js/index/sw/manifest/config/setup/
  privacy/styles + the reminder edge fn are now "Treadway"; deliberate internal identifiers
  (`cairn_*` keys, `window.CAIRN_CONFIG`, the `cairn.surge.sh` origin) intentionally unchanged.
  `sw.js` shell → v8. Deployed; all 12 changed assets matched local byte-for-byte; live PWA title/
  manifest/icon read Treadway. New landscape mark visually verified at 375×812 in OLED. Naming is
  still a user-directed working brand, NOT a cleared trademark — "Treadway" is also a surname, so
  professional clearance is still required before charging the public.

## 2026-07-22
- **Earned meal-plan Cheat Days:** any task can now enable a professional Cheat Day reward and
  choose any whole-number discipline interval from a minimum of 7 scheduled days upward. Today
  shows a gold progress/earned/active tracker, an active-day hero state, and an unmistakable task
  badge; Use and End are reversible, using the reward resets its discipline cycle, and ordinary
  Trailhead progress/streaks still treat the day as fulfilled. The task editor, Manage summary,
  tutorial copy, Week/History/all-time counts, measured-task behavior, partner-safe daily status,
  and timed reminders all understand the new state. Existing task-rule JSON plus
  `completions.status = "cheat"` avoid any SQL migration. Completion history now loads in stable
  paginated batches so intervals longer than 90 days or 1,000 rows remain accurate. Shell cache
  v7 handles installed-copy refreshes. Earned, active, toggle-back, 30-day configuration,
  minimum validation, no-overflow layout, and clean browser logs passed at 375×812; the temporary
  QA fixture was removed. The web app and canonical reminder function are live; production app,
  styles, service worker, and index assets matched local byte-for-byte after deployment.
- **Trailhead brand and identity release:** replaced the customer-facing Cairn identity with
  Trailhead across launch, Today, auth/lock/onboarding, tutorial, Home Screen metadata, formal
  privacy policy, setup guide, exports, reminders, and account copy. A new shared four-stone mark
  with a rising trail now powers the code-native UI, realistic SVG/180/192/512 installed icons,
  a restrained launch settle/draw, a prominent animated-once Today wordmark, tutorial bookends,
  and a one-shot completion pulse. Shell cache v6 handles existing-device refreshes; the live
  origin and `cairn_*` compatibility identifiers intentionally remain. Sign-in, populated Today,
  tutorial cover, Light/OLED, launch handoff, no-overflow geometry, and clean logs passed at
  375×812; the temporary QA file was removed. No SQL is required. Existing users must delete and
  re-add the Home Screen icon to receive the Trailhead name/art. Because Salesforce actively uses
  Trailhead/Trailhead GO, this user-directed working/private brand remains blocked from a paid
  public launch pending professional clearance or another rename. The web release and reminder
  function are live; eight production assets matched local byte-for-byte, and the live phone-size
  sign-in view reports Trailhead across document/PWA/UI metadata with no warnings or overflow.
- **Professional current-UI tutorial overhaul:** rebuilt `runTour()` around the unified day
  stone, real Add control, direct task gestures, rest, the close ritual (then Cairn Close; now
  Trailhead Close), Weekly Trail, History,
  task management, reminders/quiet hours, the narrow partner boundary, appearance, and data
  controls. The original traveling spotlight, Back/Skip flow, Home Screen guidance, and original
  stone-stack bookends remained in this milestone; the later Trailhead identity release replaced
  those bookends with the shared Trailhead mark. The tutorial otherwise uses polished material
  captions, animated progress stones, clamped
  phone-safe placement, crisp target exposure, and deeper blur for showcase moments. Blank new
  accounts receive a non-persistent animated gesture card instead of losing the swipe/hold lesson
  or being seeded with fake data. First-run launch, every blank-account step/finale, populated
  real-row targeting, and Settings → See the tutorial again all passed local browser QA. Keyboard
  arrows/Escape, keyboard focus trapping, background-scroll locking, reduced motion,
  accessibility dialog semantics, and shell cache v5 complete the production pass; real-iPhone
  pacing remains the final feel check. The release is live; production app.js, styles.css, and
  sw.js matched local byte-for-byte, and the temporary QA fixture is absent from production.
- **Production activation, secret rotation, and public privacy policy:** applied
  `cairn-product-upgrade.sql` to the live Supabase project; rotated the VAPID key pair and
  CRON_SECRET together; updated all related Edge secrets; recreated the five-minute reminder
  schedule without writing the real secret into tracked SQL; and confirmed the new-secret probe
  succeeds. Auth signups, confirmation, Site URL, and redirect were verified. A live isolated
  suite confirmed the real owner admin row, pending-user write denial, owner-policy approval,
  reciprocal linking, narrow profile sharing, one-per-day Proud deduplication, two-sided unlink,
  and complete test-account cleanup. The web app now carries the rotated public key, a bumped
  shell cache, and a formal public privacy policy naming the operator/contact and defining data,
  retention, rights, and material-change notice terms. Only per-phone reminder resubscription and
  real two-device notification QA remain.
- **Cairn Close, Weekly Trail, private Proud nudge, and account trust release:** Today now closes
  with a win, honest line, and tomorrow's first stone; yesterday's intention carries forward;
  Week tells a rolling seven-day story with memories and rhythm. Reciprocal partners can send one
  fixed, private Proud signal per Mountain-Time day without sharing tasks, progress details, or
  journal text. Account work adds fail-closed approval/RLS, narrow partner-profile access,
  password recovery/change, complete data export, password-verified deletion (including pending
  users), and an accurate privacy overview that was superseded by the formal launch policy.
  Independent reviews found and fixed a
  first-save Close race, migration-time local-data loss, repeated seal motion, rerun auto-
  approval, relationship probing, broad profile/nudge access, relink overwrite, false delivery,
  and uncertain destructive-action wording. Legacy setup copies were retired and tracked
  credentials removed. Both Edge Functions were deployed and their unauthorized boundaries
  verified; the web release is live, four production asset hashes match local exactly, and live
  375×812 sign-in/privacy checks have no browser errors or overflow. The later production-
  activation entry above completed the database and credential work.
- **Swipe/drag performance pass:** pointer movement now records only the newest finger position
  and paints at most once per animation frame instead of writing transforms and action classes on
  every raw event. Row and reorder motion use compositor-friendly `translate3d`; swipe direction
  and armed-state classes change only when their thresholds actually change; `will-change` is
  scoped to the active gesture so idle lists keep no unnecessary layers. The final pointer
  position is flushed before a drag drop is resolved. At 375×812, short-swipe snap-back, right-
  swipe Edit, left-swipe Delete, and Undo all passed with no current browser errors. Real-iPhone
  frame pacing remains the decisive check.
- **Today command-center redesign:** replaced the scattered header/summary/chips with one unified
  "day stone" that clearly orders date + sync, progress, daily message, completion/streak/water
  metrics, and rest/save controls. Remaining task groups now read as a continuous marked path;
  hydration is a compact daily rhythm; partner status is a quiet signal; completed work is a
  placed-stones ledger; the synced note is now a deliberate reflection ritual; and the tab bar is
  a floating piece of persistent app chrome. Existing mutations, ordering, offline sync, gestures,
  tour selectors, and reduced-motion guarantees are preserved.
  Browser review also exposed and fixed the app shell growing to document height: `#app` now
  constrains itself to the actual viewport so `.scroll` is the native-style scroller and the
  floating tab bar remains present at the bottom instead of appearing after all page content.
  Verified at 375×812 in populated, 100%-complete, written-reflection, Light, OLED, and blank new-
  member states; starter → first marker, reflection sheet, scroll containment, and tab hide/show
  all worked with no browser warnings/errors. Real-device touch feel and 60fps remain unverified.
- **Flagship motion pass, phase 1:** added a sub-900ms, tap-to-skip cold launch ritual whose five
  weighted stones settle into a cairn while data loads behind it; when Today is ready in time,
  the stack travels into the progress ring as a shared element. The tutorial spotlight now
  travels/morphs between targets, gently pulses the highlighted control, carries progress dots,
  staggers the welcome copy, and closes by completing the same cairn stack. All paths honor
  reduced motion and keep animation state outside the render-replaced app DOM. The later
  Trailhead identity release superseded only the logo geometry and handoff destination: four
  branded stones now travel to the Today wordmark instead of the progress ring.
- **Flagship motion pass, phase 2:** synchronized completion FLIP with the decelerating ring and
  odometer, added restrained 25/50/75% acknowledgements plus weighted gold stone fragments at
  100%, and made streak increments roll. Hydration now fills by transform with a slow liquid
  glint and add-water ripple. Lists enter in 30ms row staggers; tabs transition directionally
  with a traveling indicator; drag lift grows its shadow and haptics on drop; toasts rise from
  the bottom edge; empty states breathe; and sheet scroll tops gain resisted rubber-banding.
  The direct-manipulation sheet path is also explicitly bypassed under reduced motion.
  Browser QA at 375×812 verified the stagger delays, ring target/odometer, milestone class,
  hydration transform/ripple, both tab directions, spotlight target pulse and transform-only
  travel, 14 progress dots, final five-stone bookend, launch timeout, and tap-to-skip; no console
  warnings/errors. True touch feel and 60fps remain real-iPhone checks.
- **Project put under git** (local repo, no remote). Baseline `9f7f24b`, 92 files. `.gitignore`
  extended to exclude secrets (`*KEEP-SECRET*`, `.env*`, `*.pem`) on top of the existing build
  artifact rules; verified the VAPID/CRON secret file is untracked. Rollback path now exists for
  `Web/app.js`, which previously had none.
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
- **Access hub / admin gate** (historical; superseded by `cairn-product-upgrade.sql`): owner-only
  Members screen to approve/deny requests; new users land pending. The former `access-hub.sql` is
  retired and must not be run because its old rerun behavior could promote pending applicants.
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

# Treadway (formerly Trailhead, formerly Cairn) — Key Decisions

_Last updated: 2026-08-03. Brief rationale for choices that aren't obvious from the code._

- **Renamed Trailhead → Treadway (2026-07-23), user-directed.** Trailhead collides head-on with
  Salesforce's active Trailhead/Trailhead GO brand — a launch-blocking conflict flagged in the
  prior handoff. The owner asked for a never-used stone/trail name; web research (not legal
  clearance) rejected Waystone, Whetstone, Cobble, Daystone, and Esker (all had software/app
  users) and found **Treadway** clean in the software space. A treadway is the worn walking
  surface of a trail — the ground you actually cover — which fits a daily-discipline app better
  than a trail's *entrance* (Trailhead) did. **Still not a cleared trademark:** "Treadway" is also
  a surname, so a professional search is required before charging the public. See [[naming-and-domain-are-launch-blockers]].
- **The mark's geometry follows the name's meaning.** Trailhead was a vertical **cairn stack**;
  Treadway is **four flat stones stepping into the distance along a rising path**, way drawn
  behind the stones so it shows through the gaps. When the metaphor changes, the logo changes —
  a text-only swap would have left a stacked-stones mark contradicting the new name. The in-app
  SVG shares its path geometry with the app icon (one source of truth for the identity), so the
  icon and mark always match; only fills differ (icon = gray stone gradients, in-app = accent mix).
- **Internal identifiers stay `cairn_*` across both renames.** localStorage keys, `CAIRN_CONFIG`,
  SQL filenames, the repo directory, and the `cairn.surge.sh` origin are deliberately NOT renamed:
  changing storage keys would silently sign everyone out and orphan their per-device lock/tour/
  theme flags, and changing the origin would break Supabase auth redirects and push subscriptions.
  Brand lives in copy and assets; identity lives in stable keys. See [[cairn-surge-origin-is-load-bearing]].

- **Cheat Days are an earned task state, not a separate calendar or database feature.** Any task
  may opt in through `rule.cheat`, with a hard minimum of 7 disciplined scheduled completions and
  no arbitrary maximum. The activated reward uses `completions.status = "cheat"`, which the
  existing unconstrained text column already accepts. It fulfills ordinary app progress and
  streaks but never advances the separate discipline run; a prior Cheat Day or missed scheduled
  completion resets that run. This keeps a reward from punishing the user's main Trailhead streak
  without falsely calling the reward another disciplined meal-plan day. Full completion history
  is loaded in deterministic 1,000-row pages so long custom intervals remain honest. Storing the
  config in rule JSON and the use in completions makes the behavior sync/offline/export-safe with
  no SQL migration, new table, cron, or local-only counter.

- **Trailhead is the visible working brand, with a deliberate commercial hold.** The user
  explicitly selected Trailhead after being warned that Salesforce actively uses Trailhead and
  Trailhead GO. The app therefore shows Trailhead everywhere the customer sees the product, but
  this choice is not represented as trademark-cleared. Do not launch paid public marketing under
  this name until a qualified trademark search clears it or a lower-conflict name is chosen.

- **Keep the current origin and compatibility IDs during the visual rebrand.** The live address
  stays `cairn.surge.sh`; Supabase redirects, sessions, web-push origin, `CAIRN_CONFIG`, `cairn_*`
  device keys, repo paths, and SQL names remain unchanged. Renaming those internals would create
  migration risk without improving the visible brand. Existing installed PWA names/icons require
  deleting and re-adding the Home Screen shortcut; there is no SQL or account-data migration.
  The obvious `trailhead.surge.sh` hostname is already owned by an unrelated site titled
  `trailhead.app`, so it is explicitly prohibited as a deploy target or user-facing link.

- **One identity geometry, restrained motion.** The installed icon, inline app mark, launch,
  Today lockup, auth, and tutorial all use the same four-stone/rising-route shape. Startup settles
  stones and draws the route once; Today enters once per session and only pulses after a completed
  task. No continuous logo loop or pointer-time work was added, preserving gesture frame pacing.

- **Impeccable polish = refinement, not redesign.** The `/impeccable` pass treated the stones/path
  visual world (day stone, markers, small-caps kickers, the ritual copy) as the committed identity
  and only fixed mechanics: WCAG-AA contrast, hierarchy (dissolving the nested stats card), gesture
  discoverability, and keyboard/screen-reader access. Craft-floor's blanket "no kicker/eyebrow" and
  "no hero-metric" defaults were deliberately NOT applied — the incumbent world (which the user
  loves) overrides category defaults per the skill's own rule. **Contrast was chosen over the dim
  aesthetic:** "quiet/premium" is kept via weight, spacing, and restraint, not by letting secondary
  text fail AA. `--faint` is now the quietest tier that still passes 4.5:1; never revert it to the
  old sub-3:1 greys to look "calmer."

- **Current sellability work stays web-first.** The user explicitly deferred widgets, HealthKit,
  and other native-only surfaces until they have the paid Apple Developer account. The active
  pass therefore combines daily closing/weekly memory, private partner encouragement, and
  trustworthy web account/data controls on the existing Supabase PWA.

- **Structured closes extend notes instead of replacing them.** Existing `notes.text` remains the
  compatible honest-line field; optional `notes.close_data` carries versioned win/tomorrow/
  closed-at metadata. Old cached strings and pre-migration server rows must remain readable, and
  yesterday's intention is presentation only—never an automatically created or reordered task.

- **Partner encouragement is fixed, private, and server-authorized.** The intended nudge is one
  reciprocal partner signal per Mountain-Time day with no arbitrary message, task, progress, or
  journal payload. It must call a direct RPC rather than the offline outbox so an old message can
  never surprise-send later. Unlinking must clear both sides atomically before this ships.

- **Partner profile sharing is a narrow RPC, not row-level profile access.** Postgres RLS grants
  whole rows, so a profile SELECT policy would expose settings beyond name/accent to a determined
  client. `get_partner_profile()` verifies a reciprocal approved link and returns only those two
  presentation fields; partner daily counts remain in the purpose-built `daily_status` table.

- **Commercial trust means accurate boundaries before billing.** This pass does not invent a
  paid plan without a provider, price, or legal setup. It instead hardens approval in Postgres,
  makes access verification fail closed (with a legacy-table-missing compatibility exception),
  clears identity-bound cache/outbox on sign-out, completes data export, states that reflections
  are not E2E encrypted, and adds password recovery/change plus authenticated account deletion.

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

- **Access is fail-closed, with bounded offline continuity.** Unknown membership-check errors do
  not unlock the app. A device that previously confirmed approval may open its account-scoped
  cached view offline, while server RLS still rejects any no-longer-approved remote access.
  Migration reruns never promote pending users; only the known owner is force-restored as admin.

- **The public privacy page is the formal launch policy.** It names Paxton Raithel as the Colorado
  operator and `paxtonraithel@gmail.com` as the support/privacy contact, and covers scope, data
  categories, purposes, narrow partner sharing, Supabase/Surge/push providers, retention,
  security and non-E2E limits, user requests/appeals, children, processing locations, and a
  material-change notice process. Do not regress it to vague “early access” copy before billing.

- **Themes: accent syncs (identity), light/dark/oled is device-local (preference).** Accent
  lives in the profile; theme in localStorage.

- **Handoff files (this + PROJECT_CONTEXT/TODO/CHANGELOG) are maintained every significant
  change** because sessions have low context limits and may hand off at any time.
  `PROJECT_CONTEXT.md` is current operational truth; `TODO.md` contains only unfinished or
  externally blocked work; `DECISIONS.md` records durable rationale; `CHANGELOG.md` preserves
  shipped history. Historical branding may remain when it identifies an old milestone, but it
  must be labeled as historical or superseded whenever it could mislead the next agent.

- **Motion is transform/opacity-only and survives full DOM replacement in JS.** Launch and tour
  overlays sit outside `#app`; anything that crosses `render()` keeps its state in globals. The
  cold launch is skippable, runs only when the script boots, and self-dismisses below 900ms so it
  never gates data loading or interaction. Reduced-motion bypasses JS motion entirely.
  Spotlight geometry is assigned once per step, then travels through a FLIP-style transform;
  the drag shadow is a static shadow layer whose transform/opacity sells the rise.

- **The tutorial teaches the real UI without seeding tutorial data.** Current elements are
  spotlighted after `render()` switches tabs and scrolls them into view. If a blank new account
  has no task row, an overlay-only animated gesture card demonstrates tap/swipe/hold; it never
  enters `state`, localStorage, the outbox, or Supabase. Target steps use a crisp cutout while
  caption/showcase steps deliberately use stronger blur and lower exposure. This preserves the
  user's blank-page promise and keeps Settings replay identical to first-run onboarding.

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

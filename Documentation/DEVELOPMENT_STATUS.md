# Treadway — Development Status

Last updated: 2026-08-06

## Product snapshot

### Deployed Treadway PWA — primary product

The working product is an access-gated, installable PWA at `https://cairn.surge.sh`.
It includes auth, per-user RLS, cross-device sync, offline continuity, recurring tasks,
hydration, streak/rest/save behavior, Treadway Close, Weekly Trail, earned Cheat Days,
narrow partner accountability, data export/deletion, themes, a guided tutorial, and
scheduled web-push reminders.

Weekly Trail now includes Treadway Brief: a deterministic, locally executed context engine that
shows confidence and evidence provenance before preparing a versioned prompt for a user-chosen AI
chat. It makes no model/network call, excludes private Close text by default, and requires an
explicit copy action. The production engine has a Node evaluation suite covering exact metrics,
ranking, grounding instructions, privacy opt-in/out, determinism, immutability, and edge cases.

Desktop browser QA has covered 375×812 containment, light/OLED presentation, major
state transitions, keyboard task activation, reduced-motion handling, and clean console
behavior. The repository now adds repeatable syntax/PWA invariant checks. Real-iPhone
gesture feel, safe-area pacing, VoiceOver, and end-to-end push delivery remain explicit
manual checks; they are not implied by desktop or unit tests.

Treadway Brief card and sheet presentation were visually checked with synthetic data in dark and
light themes. Its prompt privacy behavior was inspected at runtime: default output omitted all
Close prose, and the opt-in payload included it. Clipboard behavior still depends on the browser/
OS permission surface and should be confirmed once on the installed iPhone PWA after deployment.

### Native Apple prototype — secondary research track

The repository also contains roughly 55 Swift source files under the historical Cairn
internal name. On 2026-08-06, the macOS local-only target built successfully with Xcode
26.6 and code signing disabled. The multiplatform CloudKit/widget/App Intents distribution
path still requires Apple signing and device-level validation and is not represented as
feature-parity with the deployed web product.

`CairnCore` is the Foundation-only domain package shared by the native prototype. Run
`swift test` and `swift run cairncore-verify` from `CairnCore/` for its current result.

## Native implementation detail

Anything marked ✅ below has compiled tests or a recorded build verification. Anything
marked ✍️ is authored but still needs the relevant signed Xcode/device verification.

## Legend
✅ done & verified · ✍️ authored, build in Xcode · ⬜ not started

## Phase 1 — Core logic (`CairnCore`) ✅
- ✅ Injectable `Clock` / `FixedClock` (no scattered `Date()`)
- ✅ `MountainTime` (America/Denver), DST-correct day math, 23h/25h transition days
- ✅ `Weekday`, `TimeOfDay`, `CalendarDay`, `TaskTiming`
- ✅ `RecurrenceRule` + `RecurrenceEngine` (daily, weekdays, weekly, monthly w/ clamp,
  every-N-days, one-time; start/end window, pause, skip; next-occurrence)
- ✅ `TaskModel`, `Subtask`, `Category`, `CompletionRecord` (natural key), `Priority`, `TaskGroup`
- ✅ `HydrationDay` / `HydrationGoal` (ml-canonical, oz display, no negatives, corrections)
- ✅ `StreakCalculator` (current/longest/rate, off-days neutral, pending-today neutral)
- ✅ `NotificationPlanner` (skips completed/skipped/paused/archived; stable ids; intervals)
- ✅ `TodayBuilder` (grouping, sorting, completion %, calm summary)
- ✅ `AsiaSession` (Sun–Thu 6–8pm, next-session, live)
- ✅ `DefaultRoutine` seed (7 tasks) + `DataArchive` JSON export/import
- ✅ `MergeResolver` (dedupe completions/tasks/hydration for CloudKit sync)
- ✅ XCTest suite (`Tests/CairnCoreTests`, runs in Xcode) + CLT verify harness

## Phase 2 — Persistence (SwiftData + CloudKit) ✍️
- ✍️ `@Model` entities + mapping to/from `CairnCore` value types
- ✍️ `Store` actor (CRUD, reorder, archive, completion, hydration)
- ✍️ `ModelContainer` config for CloudKit private DB, offline-first

## Phase 3 — App shell & navigation ✍️
- ✍️ Multiplatform `App`, adaptive nav (iOS tabs / macOS sidebar), keyboard shortcuts

## Phase 4 — Screens ✍️
- ✍️ Today, Week, History, Settings, Task Editor, Hydration, Onboarding

## Phase 5 — Notifications ✍️
- ✍️ `NotificationManager` (permission, diff/reschedule, summaries)

## Phase 6 — Security ✍️
- ✍️ `AppLockManager` (Face ID/Touch ID + passcode fallback), privacy cover, Keychain

## Phase 7 — Widgets & App Intents ✍️
- ✍️ WidgetKit (completion %, next tasks, hydration, trading, lock screen)
- ✍️ App Intents (complete task, add water, show today, add task, start session, open apps)

## Phase 8 — Project generation & docs ✍️
- ✍️ `project.yml` (XcodeGen) + entitlements/Info.plist + manual-Xcode fallback
- ✍️ README, ARCHITECTURE, setup/signing/CloudKit/TestFlight/distribution guides

## How to verify the core right now
```bash
cd CairnCore
swift run cairncore-verify     # 57/57 checks, exits 0
# In Xcode you can also run the XCTest target: ⌘U
```

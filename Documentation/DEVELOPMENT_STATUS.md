# Cairn — Development Status

_Personal daily discipline & checklist app for iPhone + Mac (SwiftUI, multiplatform)._

Last updated: 2026-07-20

**Snapshot:** ~55 Swift source files. Core logic package (Phase 1) is compiled and
verified (57/57 checks). Phases 2–8 authored in full.

**✅ macOS app now BUILDS AND RUNS.** Built with Xcode 26.6 via `project.mac.yml`
(free/local config), installed to `/Applications/Cairn.app`, and launched: it renders
the Mac `NavigationSplitView` sidebar UI, initializes its local SwiftData store at
`~/Library/Application Support/default.store`, and seeded the 7-task default routine +
3 categories — no crash. Fixes applied to reach this: renamed `Category`→`TaskCategory`
(SDK name clash), App Intents `static var`→`static let` (Swift 6 concurrency), passed a
`Sendable` `NotificationManager.Prefs` snapshot instead of the `@MainActor` settings
object, and gated the CloudKit/app-group container behind a `LOCAL_ONLY` flag (CloudKit
traps async without entitlements). The full multiplatform + sync + widgets build
(`project.yml`) still needs Xcode + a paid team; unchanged.

## Environment note (important)

This project was scaffolded in an environment with **Command Line Tools only (no
full Xcode)**. Consequences:

- ✅ **`CairnCore`** (the pure business-logic package) is **built and unit-verified
  here.** Run `cd CairnCore && swift run cairncore-verify` → 57/57 checks pass.
- ⏳ The **app / widget / intents targets** (SwiftUI, SwiftData, CloudKit, WidgetKit,
  App Intents, LocalAuthentication) are written as complete source but **have not
  been compiled here**, because those SDKs require full Xcode. They are meant to be
  opened and built in Xcode on your Mac. See `README.md` → "Build & run".

Anything marked ✅ below has been compiled/tested. Anything marked ✍️ is authored
but must be built in Xcode.

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

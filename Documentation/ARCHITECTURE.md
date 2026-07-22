# Cairn — Architecture & Decisions

## Goals that drive the design
Private, offline-first, fast, testable, native. Single shared SwiftUI codebase for
iPhone / iPad / Mac. All date logic anchored to **America/Denver** ("Mountain Time")
and DST-correct. No third-party services, analytics, or accounts.

## Layered structure

```
┌──────────────────────────────────────────────────────────────┐
│ Presentation (SwiftUI)   Today · Week · History · Settings ·  │
│                          Editor · Hydration · Onboarding      │
│   thin views ── ViewModels (@Observable) ── AppEnvironment    │
├──────────────────────────────────────────────────────────────┤
│ Services   NotificationManager · AppLockManager · DeepLinker  │
│            HydrationService · SyncCoordinator                 │
├──────────────────────────────────────────────────────────────┤
│ Persistence (SwiftData)  @Model entities  ── Store (actor)    │
│            ModelContainer (CloudKit private DB)               │
├──────────────────────────────────────────────────────────────┤
│ CairnCore  (Foundation-only, unit-tested, platform-agnostic)  │
│   Clock · MountainTime · RecurrenceEngine · HydrationModel ·  │
│   StreakCalculator · NotificationPlanner · TodayBuilder ·     │
│   AsiaSession · DefaultRoutine · DataArchive · MergeResolver  │
└──────────────────────────────────────────────────────────────┘
```

Shared by all targets (app, widget, intents): **CairnCore** + the SwiftData model.

### Decision 1 — Pure logic isolated in `CairnCore`
All recurrence, timezone, streak, hydration, and scheduling logic lives in a
Foundation-only Swift package with **no SwiftUI/SwiftData/UIKit**. Why: it compiles
and unit-tests on any toolchain (verified here without Xcode), keeps the riskiest
code deterministic, and is reused verbatim by the widget and intents extensions.

Domain types are **value types** (`TaskModel`, `CompletionRecord`, `HydrationDay`…).
The SwiftData `@Model` classes are a separate persistence representation that maps
to/from these. This prevents SwiftData/CloudKit concerns from leaking into logic.

### Decision 2 — Injectable `Clock`, never bare `Date()`
Domain code receives a `Clock`. Tests use `FixedClock` to pin instants (incl. DST
transition days). This is what makes midnight-reset and DST behavior testable.

### Decision 3 — America/Denver is the single source of truth
`MountainTime` owns one Gregorian calendar pinned to `America/Denver`. Every day
bucket, reset, weekday, and reminder time is computed through it, so a device set to
another timezone still resets and schedules on Mountain Time, and spring-forward /
fall-back days (23h / 25h) are handled by `Calendar`, not by adding 86 400 s.

### Decision 4 — Completion records keyed by (taskID, day)
A `CompletionRecord` has a natural key `taskID#Y-M-D`. `MergeResolver` collapses
duplicates last-writer-wins on `updatedAt`. This is how two devices completing the
same task on the same day never create duplicate records after CloudKit sync.
Recurring tasks are **not** materialized per-day; occurrences are computed on the
fly from the rule and overlaid with any completion record for that day. This keeps
the store small and avoids "phantom" rows when a rule is edited.

### Decision 5 — Notifications are a diff of a planned set
`NotificationPlanner` produces a deterministic set of `PlannedNotification`s (stable
ids) for the near horizon. `NotificationManager` diffs it against pending OS
requests and adds/removes the delta. Editing, completing, skipping, pausing, or
archiving a task simply changes the plan, so reminders reschedule correctly and are
never duplicated or sent for done/paused/archived/skipped tasks.

### Decision 6 — SwiftData + CloudKit private database
Local persistence via SwiftData; sync via the built-in CloudKit mirroring into the
user's **private** database (`iCloud.<bundle-id>`). Offline-first: all writes are
local and sync opportunistically. CloudKit requires all attributes to be optional or
have defaults and no `@Attribute(.unique)` — the model honors this and enforces
uniqueness in the `Store` layer via UUID + natural keys instead.

### Decision 7 — App lock via LocalAuthentication
`AppLockManager` uses `LAContext` with `.deviceOwnerAuthentication` (biometrics with
automatic device-passcode fallback). Lock-on-background + configurable grace period.
An app-switcher privacy cover hides content in the multitasking snapshot. Only a
single boolean preference and the lock settings live in Keychain; task data relies
on Apple Data Protection at rest.

## Concurrency
Swift 6 strict concurrency. `Store` is an `actor`. ViewModels are `@MainActor`
`@Observable`. Core value types are `Sendable`.

## Testing strategy
- Unit: `CairnCore` XCTest target (Xcode ⌘U) + `cairncore-verify` executable (CLI).
- UI: XCUITest target drives create/edit/complete/add-water/reorder/lock flows.

## Known deliberate trade-offs
See `README.md` → "Known limitations".

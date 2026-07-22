# Cairn

A private, minimal daily-discipline dashboard for **iPhone, iPad, and Mac**. One
shared SwiftUI codebase. All schedules, resets, streaks, and reminders are anchored
to **Mountain Time (America/Denver)** and are daylight-saving-correct.

> Cairn is a working project name — rename freely (see "Renaming" below).

---

## What's in the box

```
Cairn/
├── README.md                   ← start here
├── project.yml                 ← XcodeGen project definition
├── App/                        ← SwiftUI app (iOS + iPad + macOS)
│   ├── App/                    entry, environment, settings, macOS commands
│   ├── Persistence/            SwiftData @Model entities, Store actor, container
│   ├── Services/               NotificationManager, AppLockManager, DeepLinker
│   ├── Features/               Today, Week, History, Settings, Editor, Hydration,
│   │                           Onboarding, Lock
│   ├── Intents/                App Intents (Shortcuts/Siri/Spotlight/Action button)
│   ├── Shared/                 design system, haptics
│   └── Resources/              Cairn.entitlements, Assets.xcassets (see App Icon)
├── CairnCore/                  ← shared logic engine (Foundation only) — UNIT-TESTED
│   ├── Sources/CairnCore/      recurrence, Mountain-Time/DST, hydration, streaks,
│   │                           notification planning, sync merge, seed, JSON archive
│   ├── Sources/cairncore-verify/  CLI test harness (runs without Xcode)
│   └── Tests/CairnCoreTests/   XCTest suite (runs in Xcode ⌘U)
├── Widgets/                    ← WidgetKit extension (+ its entitlements)
├── UITests/                    ← XCUITest flows
└── Documentation/              ← ARCHITECTURE.md, DEVELOPMENT_STATUS.md
```

The core logic is verified. The app/widget/intents targets are complete source that
you build in Xcode — see the honest status in `Documentation/DEVELOPMENT_STATUS.md`.

---

## 1. Verify the core logic right now (no Xcode needed)

```bash
cd CairnCore
swift run cairncore-verify      # → "57 checks, 0 failure(s) ✅ ALL CORE LOGIC VERIFIED"
```

This exercises recurrence, DST/midnight math, hydration, streaks, notification
planning, sync de-duplication, the seed routine, and JSON archive round-trips.

---

## 2. Generate the Xcode project

The project is defined in `project.yml` (text, reviewable, reproducible).

```bash
brew install xcodegen
cd /path/to/Cairn
xcodegen generate           # creates Cairn.xcodeproj
open Cairn.xcodeproj
```

**Manual fallback (no XcodeGen):** create a new *Multiplatform App* in Xcode named
`Cairn`, then: add a local Swift Package reference to `CairnCore`; drag the
`App/`, `Widgets/`, and `UITests/` folders in as groups; add a *Widget Extension*
target named `CairnWidgets`; set the entitlements files under Signing & Capabilities;
and add a Unit-Test target pointing at `CairnCore/Tests`. `project.yml`
documents every target's settings if you go this route.

---

## 3. Signing

1. Open the project → **Cairn** target → **Signing & Capabilities**.
2. Set **Team** to your Apple Developer team (also settable via `DEVELOPMENT_TEAM`
   in `project.yml`). Repeat for the **CairnWidgets** target.
3. Bundle IDs default to `com.paxton.cairn` and `com.paxton.cairn.widgets` — change
   the prefix to your own reverse-domain if you like (see "Renaming").

---

## 4. iCloud container & CloudKit

The app syncs via SwiftData → **CloudKit private database** (your own iCloud; data
never touches any server we run).

1. **Cairn** target → Signing & Capabilities → **+ Capability → iCloud**.
2. Enable **CloudKit** and add the container **`iCloud.com.paxton.cairn`** (or your
   renamed id). Add the same container to the **CairnWidgets** target.
3. Add **+ Capability → App Groups** and enable **`group.com.paxton.cairn`** on both
   the app and widget targets (used for the widget snapshot + shared local store).
4. Add **+ Capability → Push Notifications** on the app target (CloudKit sync pushes).
5. Add **+ Capability → Background Modes → Remote notifications** (optional but
   recommended so sync lands in the background).
6. First run on a device signed into iCloud creates the schema automatically in the
   **Development** environment. Before shipping, open the **CloudKit Console**, verify
   the record types were created, and **Deploy Schema to Production**.

The entitlements in `App/Resources/Cairn.entitlements` and
`Widgets/CairnWidgets.entitlements` already list these — the Xcode capability UI just
provisions the matching App IDs in your account.

> If iCloud isn't available (not signed in, etc.), the app automatically falls back
> to a **local-only** store and stays fully functional offline.

---

## 5. Notifications

- No setup needed beyond running the app: it requests permission the first time it
  schedules a reminder.
- Reminders, the daily summary, and the before-bed summary all fire on Mountain-Time
  wall-clock times and are rescheduled automatically after any task edit.
- The **9:00 PM ashwagandha** reminder is created by the default routine.

---

## 6. App lock (Face ID / Touch ID)

Enable in **Settings → Security**. Uses `LAContext` device-owner authentication
(biometrics with automatic passcode fallback), lock-on-background with a configurable
grace period, and an app-switcher privacy cover. The Face ID usage string is set in
`project.yml` (`NSFaceIDUsageDescription`).

---

## 7. App Icon

`ASSETCATALOG_COMPILER_APPICON_NAME` is `AppIcon`. Add your icon:

1. Create `App/Resources/Assets.xcassets` with an **App Icon** set named `AppIcon`
   (Xcode: New File → Asset Catalog, then + → iOS/macOS App Icon).
2. Drop in a 1024×1024 PNG (single-size icons are fine on modern Xcode).
   A calm mark such as a stacked-stones / mountain glyph on a muted background fits
   the design language. Until you add one, the app builds with the default icon.

---

## 8. Testing

- **Unit (logic):** `cd CairnCore && swift run cairncore-verify`, or run the
  `CairnCoreTests` target in Xcode (⌘U). Covers daily/weekday/weekly/monthly/N-day
  recurrence, America/Denver DST (23h/25h days), midnight resets, hydration, streaks,
  skip/pause, notification scheduling, and CloudKit merge de-duplication.
- **UI:** the `CairnUITests` target drives create/edit/complete/add-water/navigation.

---

## 9. TestFlight (iPhone/iPad)

1. Set a unique bundle id you own and a distribution-capable Team.
2. Xcode → **Product → Archive** (Any iOS Device).
3. In the Organizer, **Distribute App → App Store Connect → Upload**.
4. In App Store Connect, create the app record, then add the build to **TestFlight**.
   Since it's for personal use, add yourself as an **Internal Tester** (no external
   review needed). Install via the TestFlight app.

## 10. Mac distribution

Pick one:

- **Personal / direct:** Xcode → Archive → **Distribute App → Direct Distribution**
  (Developer ID, notarized). Produces a signed `.app`/`.dmg` you can run anywhere.
- **Mac App Store:** Archive → Distribute → **App Store Connect** (requires the Mac
  App Store provisioning; same iCloud container works).
- **Just for yourself:** run from Xcode, or Archive → **Copy App** and move it to
  `/Applications`.

---

## Renaming the app / bundle id / container

Rename in this order, then re-run `xcodegen generate`:

1. `project.yml` — `name`, `bundleIdPrefix`, `PRODUCT_BUNDLE_IDENTIFIER`(s),
   `CODE_SIGN_ENTITLEMENTS` paths if you move files.
2. Entitlements — the `iCloud.…` container id and `group.…` app group.
3. Source constants — `PersistenceController.cloudKitContainerID` / `appGroupID`,
   `AppSettings.suiteName`, `WidgetSnapshotStore.appGroup`, `SharedDefaults.suite`.
   (They're all the same two strings: the container id and the app-group id.)

---

## Known limitations

- **Built where noted:** the core logic package is compiled and unit-verified; the
  SwiftUI app, widgets, and intents are complete source authored against the iOS/macOS
  SDKs but must be built in Xcode (they use SwiftData/WidgetKit/App Intents macros not
  available to command-line Swift). See `Documentation/DEVELOPMENT_STATUS.md`.
- **CloudKit schema** must be deployed to Production once (step 4) before a store
  release; development just-works on your own devices.
- **Interactive widget buttons** (complete task, add water) require iOS 17 / macOS 14+.
- **App lock on macOS** uses Touch ID where the Mac supports it, otherwise password.
- **Deep links** open MyFitnessPal / the Bible app if installed, else the website —
  there is deliberately no scraping, login, or automation of third-party apps.
- Recurrence "edit only this / this-and-future / all" is implemented by splitting the
  series (skip + one-off, or end-date + new series); history stays attached to the
  originating task id.

---

## Privacy

On-device + your private iCloud. No accounts, no analytics, no ads, no third-party
SDKs, no tracking, nothing sold. Full explanation in-app: **Settings → Privacy**.
Export everything as JSON any time; delete everything from **Settings → Data**.

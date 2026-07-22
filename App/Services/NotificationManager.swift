import Foundation
import UserNotifications
import CairnCore

/// Wraps `UNUserNotificationCenter`. Builds a plan with `NotificationPlanner`, then
/// diffs it against pending requests so edits reschedule correctly and no reminder
/// is ever duplicated or sent for a completed/skipped/paused/archived task.
actor NotificationManager {
    private let center = UNUserNotificationCenter.current()
    private let planner = NotificationPlanner()

    /// A `Sendable` snapshot of the notification-relevant preferences, built on the
    /// main actor and passed in — so this actor never reaches across isolation into
    /// the `@MainActor` `AppSettings` object.
    struct Prefs: Sendable {
        var notificationsEnabled: Bool
        var dailySummaryEnabled: Bool
        var dailySummaryTime: TimeOfDay
        var beforeBedSummaryEnabled: Bool
        var beforeBedSummaryTime: TimeOfDay
    }

    /// Ask for permission only when needed. Returns whether it's authorized.
    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Reschedule reminders for the next `horizonDays` days. Idempotent.
    func reschedule(
        tasks: [TaskModel],
        horizonDays: Int,
        startDay: CalendarDay,
        prefs: Prefs,
        statusFor: @Sendable (UUID, CalendarDay) -> CompletionStatus?
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }

        // 1) Build the desired plan.
        var planned: [PlannedNotification] = []
        let engine = RecurrenceEngine()
        var day = startDay
        for _ in 0..<max(1, horizonDays) {
            for task in tasks {
                let status = statusFor(task.id, day)
                planned += planner.notifications(
                    for: task, on: day, status: status,
                    notificationsEnabledGlobally: prefs.notificationsEnabled
                )
            }
            day = engine.addingOneDay(to: day)
        }
        // Only keep notifications in the future.
        let now = Date()
        planned = planned.filter { $0.fireDate > now }

        // 2) Diff against what's already scheduled.
        let existing = await center.pendingNotificationRequests()
        // Only reconcile task reminders here; summaries are handled separately.
        let existingIDs = Set(existing.map(\.identifier).filter { $0.hasPrefix("task#") })
        let plannedByID = Dictionary(uniqueKeysWithValues: planned.map { ("task#\($0.id)", $0) })
        let plannedIDs = Set(plannedByID.keys)

        // Remove reminders that are no longer wanted (task completed/edited/deleted).
        let toRemove = existingIDs.subtracting(plannedIDs)
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toRemove))
        }

        // Add reminders that aren't scheduled yet.
        let toAdd = plannedIDs.subtracting(existingIDs)
        for id in toAdd {
            guard let note = plannedByID[id] else { continue }
            await add(note, identifier: id)
        }

        // 3) Summary notifications.
        await scheduleSummaries(prefs: prefs, startDay: startDay)
    }

    private func add(_ note: PlannedNotification, identifier: String) async {
        let content = UNMutableNotificationContent()
        content.title = note.title
        content.body = note.body
        content.sound = .default
        content.threadIdentifier = note.threadIdentifier

        let comps = MountainTime.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: note.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private func scheduleSummaries(prefs: Prefs, startDay: CalendarDay) async {
        // Remove old summary requests first so time changes take effect.
        center.removePendingNotificationRequests(withIdentifiers: ["summary#daily", "summary#bed"])

        if prefs.dailySummaryEnabled {
            await addRepeatingDaily(
                id: "summary#daily", time: prefs.dailySummaryTime,
                title: "Today in Cairn", body: "Here's your plan for the day."
            )
        }
        if prefs.beforeBedSummaryEnabled {
            await addRepeatingDaily(
                id: "summary#bed", time: prefs.beforeBedSummaryTime,
                title: "Before bed", body: "A quick look at anything still unfinished."
            )
        }
    }

    private func addRepeatingDaily(id: String, time: TimeOfDay, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // Repeats daily at the Mountain-Time wall-clock time.
        var comps = DateComponents()
        comps.hour = time.hour
        comps.minute = time.minute
        comps.timeZone = MountainTime.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
    }
}

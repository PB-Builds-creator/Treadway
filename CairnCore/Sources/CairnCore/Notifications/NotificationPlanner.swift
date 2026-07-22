import Foundation

/// Turns tasks + reminder rules + completion state into a concrete set of
/// `PlannedNotification`s for a given day. The app's notification manager diffs
/// this plan against what the OS currently has scheduled, so edits reschedule
/// correctly and completed/paused/archived/skipped tasks never notify.
public struct NotificationPlanner: Sendable {
    private let engine: RecurrenceEngine

    public init(engine: RecurrenceEngine = RecurrenceEngine()) {
        self.engine = engine
    }

    /// Build notifications for `task` on `day`. Returns [] when the task should
    /// not notify (not scheduled, paused, archived, already completed/skipped).
    public func notifications(
        for task: TaskModel,
        on day: CalendarDay,
        status: CompletionStatus?,
        notificationsEnabledGlobally: Bool
    ) -> [PlannedNotification] {
        guard notificationsEnabledGlobally else { return [] }
        guard !task.isArchived else { return [] }
        guard engine.occurs(task.schedule, on: day) else { return [] }
        // Completed or skipped => no reminders for the rest of the day.
        if status == .completed || status == .skipped { return [] }

        var result: [PlannedNotification] = []
        for reminder in task.reminders where reminder.isEnabled {
            result.append(contentsOf: resolve(reminder, task: task, day: day))
        }
        return result
    }

    private func resolve(_ reminder: ReminderRule, task: TaskModel, day: CalendarDay) -> [PlannedNotification] {
        switch reminder.kind {
        case .atTime(let time):
            guard let fire = MountainTime.date(on: day, at: time) else { return [] }
            return [make(task: task, day: day, suffix: "at-\(time.minutesSinceMidnight)", fire: fire,
                        body: task.notes.isEmpty ? "Time for \(task.title)." : task.notes)]

        case .minutesBefore(let minutes):
            guard let anchor = task.timing.anchorTime,
                  let anchorDate = MountainTime.date(on: day, at: anchor) else { return [] }
            let fire = anchorDate.addingTimeInterval(TimeInterval(-minutes * 60))
            return [make(task: task, day: day, suffix: "before-\(minutes)", fire: fire,
                        body: "\(task.title) in \(minutes) min.")]

        case .interval(let everyMinutes, let start, let end):
            guard everyMinutes > 0,
                  let startDate = MountainTime.date(on: day, at: start),
                  let endDate = MountainTime.date(on: day, at: end),
                  endDate > startDate else { return [] }
            var fires: [PlannedNotification] = []
            var cursor = startDate
            var index = 0
            while cursor <= endDate {
                fires.append(make(task: task, day: day, suffix: "int-\(index)", fire: cursor,
                                  body: "Reminder: \(task.title)."))
                cursor = cursor.addingTimeInterval(TimeInterval(everyMinutes * 60))
                index += 1
            }
            return fires
        }
    }

    private func make(task: TaskModel, day: CalendarDay, suffix: String, fire: Date, body: String) -> PlannedNotification {
        // Stable, collision-free identifier => the OS de-duplicates automatically.
        let id = "\(task.id.uuidString)#\(day.year)-\(day.month)-\(day.day)#\(suffix)"
        return PlannedNotification(
            id: id,
            taskID: task.id,
            title: task.title,
            body: body,
            fireDate: fire,
            threadIdentifier: task.categoryID?.uuidString ?? "cairn.general"
        )
    }
}

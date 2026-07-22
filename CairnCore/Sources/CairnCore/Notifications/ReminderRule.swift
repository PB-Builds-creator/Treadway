import Foundation

/// A single reminder attached to a task. A task may have multiple reminders.
public struct ReminderRule: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var kind: Kind
    public var isEnabled: Bool

    public enum Kind: Hashable, Codable, Sendable {
        /// Fire at a fixed wall-clock time on days the task occurs.
        case atTime(TimeOfDay)
        /// Fire a number of minutes before the task's anchor time.
        case minutesBefore(Int)
        /// Repeating interval reminders across a daytime window (used by hydration).
        case interval(everyMinutes: Int, start: TimeOfDay, end: TimeOfDay)
    }

    public init(id: UUID = UUID(), kind: Kind, isEnabled: Bool = true) {
        self.id = id
        self.kind = kind
        self.isEnabled = isEnabled
    }
}

/// A concrete, resolved notification the scheduler should register with the OS.
/// Produced by `NotificationPlanner` from tasks + completion state, so the app
/// never schedules reminders for completed/paused/archived/skipped tasks.
public struct PlannedNotification: Hashable, Sendable, Identifiable {
    public var id: String            // stable identifier => prevents duplicates
    public var taskID: UUID
    public var title: String
    public var body: String
    public var fireDate: Date
    public var threadIdentifier: String

    public init(id: String, taskID: UUID, title: String, body: String, fireDate: Date, threadIdentifier: String) {
        self.id = id
        self.taskID = taskID
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.threadIdentifier = threadIdentifier
    }
}

import Foundation

/// A wall-clock time of day (hour + minute), time-zone independent until resolved.
public struct TimeOfDay: Hashable, Codable, Comparable, Sendable {
    public var hour: Int      // 0...23
    public var minute: Int    // 0...59

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// e.g. "9:00 PM". Uses a fixed-format 12-hour representation.
    public var displayString: String {
        let period = hour < 12 ? "AM" : "PM"
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", displayHour, minute, period)
    }

    // Common anchors used by the default routine.
    public static let ashwagandha = TimeOfDay(hour: 21, minute: 0) // 9:00 PM
    public static let asiaSessionStart = TimeOfDay(hour: 18, minute: 0) // 6:00 PM
    public static let asiaSessionEnd = TimeOfDay(hour: 20, minute: 0)   // 8:00 PM
}

/// An optional scheduled window for a task: either a specific time, a flexible
/// span, or none (a "sometime today" task).
public enum TaskTiming: Hashable, Codable, Sendable {
    case anytime
    case at(TimeOfDay)
    case window(start: TimeOfDay, end: TimeOfDay)

    /// The time used for sorting/grouping and for the primary reminder.
    public var anchorTime: TimeOfDay? {
        switch self {
        case .anytime: return nil
        case .at(let t): return t
        case .window(let start, _): return start
        }
    }
}

import Foundation

/// Describes when a task recurs. Time-zone-independent; evaluated against
/// Mountain-Time calendar days by `RecurrenceEngine`.
public enum RecurrenceRule: Hashable, Codable, Sendable {

    /// Every day.
    case daily

    /// On the given weekdays (e.g. Sun–Thu for the Asia session).
    case weekdays(Set<Weekday>)

    /// Once per week on a single weekday.
    case weekly(Weekday)

    /// Once per month on a given day-of-month (1...31). If the month is shorter,
    /// the occurrence clamps to the last valid day (e.g. 31 -> Feb 28/29).
    case monthly(day: Int)

    /// Every N days, counted from an anchor calendar day (inclusive).
    case everyNDays(interval: Int, anchor: CalendarDay)

    /// A single, non-repeating occurrence on a specific day.
    case oneTime(CalendarDay)

    /// A human-readable summary for UI.
    public var summary: String {
        switch self {
        case .daily:
            return "Every day"
        case .weekdays(let days):
            if days == Weekday.sundayThroughThursday { return "Sun–Thu" }
            if days == Set(Weekday.allCases) { return "Every day" }
            if days == [.saturday, .sunday] { return "Weekends" }
            if days == [.monday, .tuesday, .wednesday, .thursday, .friday] { return "Weekdays" }
            return days.sorted().map(\.shortName).joined(separator: ", ")
        case .weekly(let day):
            return "Every \(day.fullName)"
        case .monthly(let day):
            return "Monthly on day \(day)"
        case .everyNDays(let interval, _):
            return interval == 1 ? "Every day" : "Every \(interval) days"
        case .oneTime:
            return "One time"
        }
    }
}

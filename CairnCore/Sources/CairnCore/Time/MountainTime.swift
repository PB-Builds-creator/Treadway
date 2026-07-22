import Foundation

/// Centralized America/Denver ("Mountain Time") calendar utilities.
///
/// The entire app anchors recurring tasks, resets, streaks, and scheduling to
/// America/Denver rather than the device's current time zone, and handles
/// daylight-saving transitions correctly. Displaying to the user, this is called
/// "Mountain Time".
public enum MountainTime {

    /// The IANA time zone. `America/Denver` observes DST (MST/MDT).
    /// Force-unwrap avoided: `.gmt` is a safe fallback that never crashes; the
    /// identifier is a compile-time constant known-good on all Apple platforms,
    /// so the fallback is effectively unreachable but keeps us crash-free.
    public static let timeZone: TimeZone = TimeZone(identifier: "America/Denver") ?? .gmt

    /// A Gregorian calendar pinned to Mountain Time. Used for ALL day/weekday math.
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// The user-facing label for the time zone.
    public static let displayName = "Mountain Time"

    /// Abbreviation valid for a given instant ("MST" in winter, "MDT" in summer).
    public static func abbreviation(at date: Date) -> String {
        timeZone.abbreviation(for: date) ?? "MT"
    }

    /// The start of the Mountain-Time day (local midnight) that contains `date`.
    /// This is the canonical "day bucket" used for resets and grouping.
    public static func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// The Mountain-Time calendar day (year/month/day) containing `date`.
    public static func day(for date: Date) -> CalendarDay {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return CalendarDay(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    /// Whether two instants fall on the same Mountain-Time calendar day.
    public static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// The next Mountain-Time midnight strictly after `date` — i.e. the moment the
    /// daily reset fires. Robust across DST "spring forward"/"fall back" days,
    /// because it is derived from `startOfDay` + one calendar day.
    public static func nextMidnight(after date: Date) -> Date {
        let startOfToday = startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
    }

    /// Resolve a wall-clock time-of-day on a specific Mountain-Time day to an
    /// absolute `Date`. Handles DST gaps/overlaps via `Calendar`'s resolution.
    public static func date(on day: CalendarDay, at time: TimeOfDay) -> Date? {
        var components = DateComponents()
        components.year = day.year
        components.month = day.month
        components.day = day.day
        components.hour = time.hour
        components.minute = time.minute
        components.timeZone = timeZone
        return calendar.date(from: components)
    }
}

/// A time-zone-independent calendar day (a real day on the wall calendar).
public struct CalendarDay: Hashable, Codable, Comparable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// The absolute start-of-day instant for this calendar day in Mountain Time.
    public var startOfDay: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = MountainTime.timeZone
        return MountainTime.calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    /// The Mountain-Time weekday for this day.
    public var weekday: Weekday {
        let index = MountainTime.calendar.component(.weekday, from: startOfDay)
        return Weekday(gregorianComponent: index)
    }
}

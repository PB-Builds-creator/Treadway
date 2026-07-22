import Foundation

/// An injectable source of "now".
///
/// Nothing in the domain layer is allowed to call `Date()` directly. Every piece
/// of logic that needs the current instant receives a `Clock`, which makes all
/// date/recurrence/streak logic deterministic and unit-testable (including across
/// daylight-saving transitions and year boundaries).
public protocol Clock: Sendable {
    var now: Date { get }
}

/// The real system clock. Used by the app at runtime.
public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// A clock pinned to a fixed instant. Used by tests and previews.
public struct FixedClock: Clock {
    public var now: Date
    public init(_ now: Date) { self.now = now }

    /// Convenience initializer from Mountain-Time wall-clock components.
    public init(mountain year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = MountainTime.timeZone
        // Force-unwrap avoided: fall back to reference date if components are invalid.
        self.now = MountainTime.calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

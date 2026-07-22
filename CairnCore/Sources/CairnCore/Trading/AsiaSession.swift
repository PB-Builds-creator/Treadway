import Foundation

/// Helpers for the Asia Trading Session (Sun–Thu, 6:00–8:00 PM Mountain Time).
/// Used by the trading widget and the "Start Asia Trading Session" intent.
public struct AsiaSession: Sendable {
    private let engine = RecurrenceEngine()

    public init() {}

    /// The schedule the seed routine installs for the session.
    public var schedule: RecurrenceEngine.Schedule {
        RecurrenceEngine.Schedule(
            rule: .weekdays(Weekday.sundayThroughThursday),
            startDay: MountainTime.day(for: Date(timeIntervalSinceReferenceDate: 0))
        )
    }

    public struct Occurrence: Hashable, Sendable {
        public var start: Date
        public var end: Date
    }

    /// The next session starting at or after `now`. If a session is in progress,
    /// returns that in-progress session.
    public func nextSession(now: Date, searchDays: Int = 8) -> Occurrence? {
        let today = MountainTime.day(for: now)
        var cursor = today
        for _ in 0...searchDays {
            if engine.matchesRule(.weekdays(Weekday.sundayThroughThursday), on: cursor, startDay: today) {
                if let start = MountainTime.date(on: cursor, at: .asiaSessionStart),
                   let end = MountainTime.date(on: cursor, at: .asiaSessionEnd) {
                    // Skip sessions that have already ended.
                    if end > now {
                        return Occurrence(start: start, end: end)
                    }
                }
            }
            cursor = engine.addingOneDay(to: cursor)
        }
        return nil
    }

    public func isLive(now: Date) -> Bool {
        guard let session = nextSession(now: now) else { return false }
        return now >= session.start && now <= session.end
    }

    /// Default subtasks the user can edit or remove.
    public static let defaultSubtasks: [String] = [
        "Review higher-timeframe market bias",
        "Review economic news",
        "Check DXY",
        "Mark important levels",
        "Review risk limit",
        "Journal trades after the session"
    ]
}

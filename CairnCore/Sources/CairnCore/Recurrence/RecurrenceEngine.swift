import Foundation

/// Pure, deterministic evaluation of recurrence rules against Mountain-Time days.
///
/// This is the most safety-critical logic in the app and is exhaustively unit
/// tested (daily, weekday, weekly, monthly, N-day, one-time, DST boundaries,
/// month/year/leap-year boundaries, start/end windows, pauses).
public struct RecurrenceEngine: Sendable {

    public init() {}

    /// A schedule couples a recurrence rule with a validity window and pause state.
    public struct Schedule: Hashable, Codable, Sendable {
        public var rule: RecurrenceRule
        public var startDay: CalendarDay
        public var endDay: CalendarDay?          // inclusive; nil = open-ended
        public var isPaused: Bool                // recurrence temporarily suspended
        /// Specific days the user chose to skip (per-occurrence "skip for today").
        public var skippedDays: Set<CalendarDay>

        public init(
            rule: RecurrenceRule,
            startDay: CalendarDay,
            endDay: CalendarDay? = nil,
            isPaused: Bool = false,
            skippedDays: Set<CalendarDay> = []
        ) {
            self.rule = rule
            self.startDay = startDay
            self.endDay = endDay
            self.isPaused = isPaused
            self.skippedDays = skippedDays
        }
    }

    /// Whether a task with `schedule` is due on `day` (Mountain-Time calendar day).
    /// A skipped day returns `false` here but is still tracked separately so the
    /// UI can distinguish "skipped" from "not scheduled".
    public func occurs(_ schedule: Schedule, on day: CalendarDay) -> Bool {
        guard !schedule.isPaused else { return false }
        guard day >= schedule.startDay else { return false }
        if let end = schedule.endDay, day > end { return false }
        if schedule.skippedDays.contains(day) { return false }
        return matchesRule(schedule.rule, on: day, startDay: schedule.startDay)
    }

    /// Whether the rule itself (ignoring window/pause/skip) matches a day.
    public func matchesRule(_ rule: RecurrenceRule, on day: CalendarDay, startDay: CalendarDay) -> Bool {
        switch rule {
        case .daily:
            return true

        case .weekdays(let days):
            return days.contains(day.weekday)

        case .weekly(let weekday):
            return day.weekday == weekday

        case .monthly(let dom):
            return day.day == clampedDayOfMonth(dom, year: day.year, month: day.month)

        case .everyNDays(let interval, let anchor):
            guard interval > 0 else { return false }
            let delta = daysBetween(anchor, day)
            return delta >= 0 && delta % interval == 0

        case .oneTime(let target):
            return day == target
        }
    }

    /// The next day (on or after `day`) on which the schedule occurs, if any.
    public func nextOccurrence(_ schedule: Schedule, onOrAfter day: CalendarDay, searchLimitDays: Int = 366 * 2) -> CalendarDay? {
        var cursor = max(day, schedule.startDay)
        var steps = 0
        while steps <= searchLimitDays {
            if let end = schedule.endDay, cursor > end { return nil }
            if occurs(schedule, on: cursor) { return cursor }
            cursor = addingOneDay(to: cursor)
            steps += 1
        }
        return nil
    }

    // MARK: - Day arithmetic (routed through Mountain-Time calendar)

    /// The day-of-month a monthly rule actually lands on, clamped to month length
    /// so "31st" becomes Feb 28/29, Apr 30, etc.
    public func clampedDayOfMonth(_ requested: Int, year: Int, month: Int) -> Int {
        let length = daysInMonth(year: year, month: month)
        return min(max(requested, 1), length)
    }

    public func daysInMonth(year: Int, month: Int) -> Int {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let cal = MountainTime.calendar
        guard let date = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: date) else {
            return 28 // safe minimum; never trap
        }
        return range.count
    }

    /// Signed number of calendar days from `a` to `b` (b - a) in Mountain Time.
    public func daysBetween(_ a: CalendarDay, _ b: CalendarDay) -> Int {
        let cal = MountainTime.calendar
        let start = cal.startOfDay(for: a.startOfDay)
        let end = cal.startOfDay(for: b.startOfDay)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    public func addingOneDay(to day: CalendarDay) -> CalendarDay {
        MountainTime.day(for: MountainTime.calendar.date(byAdding: .day, value: 1, to: day.startOfDay) ?? day.startOfDay.addingTimeInterval(86_400))
    }
}

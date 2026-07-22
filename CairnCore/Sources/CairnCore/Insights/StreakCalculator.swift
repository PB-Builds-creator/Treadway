import Foundation

/// Computes current/longest streaks and completion rates from completion history.
/// Pure and deterministic: given the set of days a task was "successfully done",
/// it counts consecutive scheduled days, correctly skipping days the task was not
/// scheduled (so a Sun–Thu task is not penalized for Friday/Saturday).
public struct StreakCalculator: Sendable {
    private let engine: RecurrenceEngine

    public init(engine: RecurrenceEngine = RecurrenceEngine()) {
        self.engine = engine
    }

    public struct Result: Hashable, Sendable {
        public var current: Int
        public var longest: Int
        public var completionRate: Double   // 0...1 over scheduled days in range
        public var scheduledCount: Int
        public var completedCount: Int
    }

    /// A day "counts as done" if its status is completed or partial. Skipped days
    /// break neither the streak nor count against it — they are neutral.
    private func countsAsDone(_ status: CompletionStatus?) -> Bool {
        status == .completed || status == .partial
    }

    /// Compute streaks for `schedule` over the inclusive range [from, through],
    /// given a lookup of completion status by day.
    ///
    /// - Parameter referenceDay: the "today" day. If the reference day is scheduled
    ///   but still pending (not yet done), it is treated as *neutral* — it does not
    ///   break the current streak — so the streak doesn't collapse just because you
    ///   haven't completed today's task yet. Defaults to `through`.
    ///
    /// The **current** streak is the trailing run of consecutive done scheduled days
    /// ending at the reference day. The **longest** streak is the longest such run
    /// anywhere in the range. Off-days (not scheduled) and explicitly skipped days
    /// are neutral and never break a streak.
    public func compute(
        schedule: RecurrenceEngine.Schedule,
        from: CalendarDay,
        through: CalendarDay,
        referenceDay: CalendarDay? = nil,
        status: (CalendarDay) -> CompletionStatus?
    ) -> Result {
        guard from <= through else {
            return Result(current: 0, longest: 0, completionRate: 0, scheduledCount: 0, completedCount: 0)
        }
        let reference = referenceDay ?? through

        var longest = 0
        var running = 0        // trailing run length; also yields the current streak
        var scheduled = 0
        var completed = 0

        var cursor = from
        while cursor <= through {
            if engine.occurs(schedule, on: cursor) {
                scheduled += 1
                if countsAsDone(status(cursor)) {
                    completed += 1
                    running += 1
                    longest = max(longest, running)
                } else if cursor == reference {
                    // Today, still pending: neutral. Preserve the prior run so the
                    // current streak reflects days completed up to yesterday.
                } else {
                    running = 0
                }
            }
            // Skipped / off days are neutral.
            cursor = engine.addingOneDay(to: cursor)
        }

        let rate = scheduled == 0 ? 0 : Double(completed) / Double(scheduled)
        return Result(
            current: running,
            longest: longest,
            completionRate: rate,
            scheduledCount: scheduled,
            completedCount: completed
        )
    }
}

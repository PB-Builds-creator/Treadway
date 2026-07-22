import Foundation

/// Pure logic that assembles the "Today" dashboard from tasks + completion state.
/// The SwiftUI view is a thin renderer over `TodaySnapshot`.
public struct TodayBuilder: Sendable {
    private let engine: RecurrenceEngine

    public init(engine: RecurrenceEngine = RecurrenceEngine()) {
        self.engine = engine
    }

    /// One task as it appears on Today, with its resolved status.
    public struct Item: Identifiable, Hashable, Sendable {
        public var task: TaskModel
        public var status: CompletionStatus
        public var id: UUID { task.id }
        public var isDone: Bool { status == .completed }
    }

    public struct Section: Identifiable, Hashable, Sendable {
        public var group: TaskGroup
        public var items: [Item]
        public var id: String { group.rawValue }
    }

    public struct Snapshot: Sendable {
        public var day: CalendarDay
        public var sections: [Section]        // only non-empty groups, sorted
        public var completedSections: [Section]
        public var completedCount: Int
        public var remainingCount: Int
        public var totalCount: Int
        public var completionFraction: Double // 0...1
        public var summary: String

        public var isAllDone: Bool { totalCount > 0 && remainingCount == 0 }
    }

    /// Build the snapshot. `status(taskID)` returns the completion status for the
    /// day, or nil for pending.
    public func snapshot(
        tasks: [TaskModel],
        on day: CalendarDay,
        status: (UUID) -> CompletionStatus?
    ) -> Snapshot {
        let due = tasks
            .filter { !$0.isArchived }
            .filter { engine.occurs($0.schedule, on: day) }

        var pendingItems: [Item] = []
        var doneItems: [Item] = []

        for task in due {
            let resolved = status(task.id) ?? .pending
            let item = Item(task: task, status: resolved)
            if resolved == .completed { doneItems.append(item) } else { pendingItems.append(item) }
        }

        let sections = groupAndSort(pendingItems)
        let completedSections = groupAndSort(doneItems)

        let total = due.count
        let completed = doneItems.count
        let remaining = total - completed
        let fraction = total == 0 ? 0 : Double(completed) / Double(total)

        return Snapshot(
            day: day,
            sections: sections,
            completedSections: completedSections,
            completedCount: completed,
            remainingCount: remaining,
            totalCount: total,
            completionFraction: fraction,
            summary: Self.summary(total: total, remaining: remaining, fraction: fraction)
        )
    }

    private func groupAndSort(_ items: [Item]) -> [Section] {
        let grouped = Dictionary(grouping: items, by: { $0.task.group })
        return grouped
            .map { Section(group: $0.key, items: sortItems($0.value)) }
            .sorted { $0.group.sortOrder < $1.group.sortOrder }
    }

    private func sortItems(_ items: [Item]) -> [Item] {
        items.sorted { a, b in
            let ta = a.task.timing.anchorTime?.minutesSinceMidnight ?? Int.max
            let tb = b.task.timing.anchorTime?.minutesSinceMidnight ?? Int.max
            if ta != tb { return ta < tb }
            if a.task.priority != b.task.priority { return a.task.priority > b.task.priority }
            if a.task.sortIndex != b.task.sortIndex { return a.task.sortIndex < b.task.sortIndex }
            return a.task.title < b.task.title
        }
    }

    /// A calm, non-gamified one-line summary.
    static func summary(total: Int, remaining: Int, fraction: Double) -> String {
        if total == 0 { return "Nothing scheduled today." }
        if remaining == 0 { return "All done for today." }
        if fraction >= 0.75 { return "Almost there — \(remaining) to go." }
        if fraction >= 0.4 { return "Good progress — \(remaining) remaining." }
        return "\(remaining) task\(remaining == 1 ? "" : "s") to complete today."
    }
}

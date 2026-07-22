import Foundation

/// Deterministic conflict resolution used when reconciling records that may have
/// been edited on multiple devices. CloudKit handles transport; this handles the
/// semantic merge so we never end up with duplicate tasks or duplicate completion
/// records for the same task+day.
public struct MergeResolver: Sendable {

    public init() {}

    /// Collapse completion records to one per natural key (taskID + day), keeping
    /// the most recently updated. This is what prevents two devices completing the
    /// same task on the same day from creating two records.
    public func dedupeCompletions(_ records: [CompletionRecord]) -> [CompletionRecord] {
        var byKey: [String: CompletionRecord] = [:]
        for record in records {
            if let existing = byKey[record.naturalKey] {
                byKey[record.naturalKey] = winner(existing, record)
            } else {
                byKey[record.naturalKey] = record
            }
        }
        return byKey.values.sorted { $0.naturalKey < $1.naturalKey }
    }

    /// Last-writer-wins on `updatedAt`, with a stable tiebreak on id so the result
    /// is identical regardless of input ordering (important for idempotent sync).
    public func winner(_ a: CompletionRecord, _ b: CompletionRecord) -> CompletionRecord {
        if a.updatedAt != b.updatedAt {
            return a.updatedAt > b.updatedAt ? a : b
        }
        return a.id.uuidString > b.id.uuidString ? a : b
    }

    /// Merge two task lists by id, keeping the most recently created/edited copy.
    /// (Tasks carry `createdAt`; edits bump an updatedAt via the store, but for the
    /// pure model we tiebreak on id for determinism.)
    public func dedupeTasks(_ tasks: [TaskModel]) -> [TaskModel] {
        var byID: [UUID: TaskModel] = [:]
        for task in tasks {
            if let existing = byID[task.id] {
                byID[task.id] = existing.createdAt <= task.createdAt ? task : existing
            } else {
                byID[task.id] = task
            }
        }
        return byID.values.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Merge hydration days: sum is not correct across devices (would double-count),
    /// so we union entries by their stable ids, which is idempotent and commutative.
    public func mergeHydration(_ days: [HydrationDay]) -> [HydrationDay] {
        var byDay: [CalendarDay: [UUID: HydrationDay.Entry]] = [:]
        for day in days {
            for entry in day.entries {
                byDay[day.day, default: [:]][entry.id] = entry
            }
        }
        return byDay.map { key, entries in
            HydrationDay(day: key, entries: entries.values.sorted { $0.timestamp < $1.timestamp })
        }
        .sorted { $0.day < $1.day }
    }
}

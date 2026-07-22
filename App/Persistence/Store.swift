import Foundation
import SwiftData
import CairnCore

/// The single gateway to persistence. A `@ModelActor` so all SwiftData access is
/// serialized off the main thread. Views/view models call these async methods and
/// receive pure `CairnCore` value types — SwiftData never escapes this layer.
@ModelActor
actor Store {
    private let resolver = MergeResolver()

    // MARK: - Tasks

    func allTasks(includeArchived: Bool = false) throws -> [TaskModel] {
        let descriptor = FetchDescriptor<TaskEntity>(sortBy: [SortDescriptor(\.sortIndex)])
        let entities = try modelContext.fetch(descriptor)
        let models = entities.map(\.model).filter { includeArchived || !$0.isArchived }
        // Defensive de-dup in case sync produced duplicate ids.
        return resolver.dedupeTasks(models)
    }

    func upsert(_ task: TaskModel) throws {
        let id = task.id
        let descriptor = FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.apply(task)
        } else {
            modelContext.insert(TaskEntity(model: task))
        }
        try modelContext.save()
    }

    func delete(taskID: UUID) throws {
        let descriptor = FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.id == taskID })
        for entity in try modelContext.fetch(descriptor) { modelContext.delete(entity) }
        // Also remove the task's completion history.
        let comps = FetchDescriptor<CompletionEntity>(predicate: #Predicate { $0.taskID == taskID })
        for entity in try modelContext.fetch(comps) { modelContext.delete(entity) }
        try modelContext.save()
    }

    func setArchived(_ archived: Bool, taskID: UUID) throws {
        let descriptor = FetchDescriptor<TaskEntity>(predicate: #Predicate { $0.id == taskID })
        if let entity = try modelContext.fetch(descriptor).first {
            entity.isArchived = archived
            try modelContext.save()
        }
    }

    /// Persist a new ordering. `orderedIDs` is the full list top-to-bottom.
    func reorder(_ orderedIDs: [UUID]) throws {
        let all = try modelContext.fetch(FetchDescriptor<TaskEntity>())
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        for (index, id) in orderedIDs.enumerated() {
            byID[id]?.sortIndex = index
        }
        try modelContext.save()
    }

    // MARK: - Categories

    func allCategories() throws -> [TaskCategory] {
        try modelContext.fetch(FetchDescriptor<CategoryEntity>(sortBy: [SortDescriptor(\.sortIndex)]))
            .map(\.category)
    }

    func upsert(_ category: TaskCategory) throws {
        let id = category.id
        let descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = category.name
            existing.symbolName = category.symbolName
            existing.sortIndex = category.sortIndex
        } else {
            modelContext.insert(CategoryEntity(category: category))
        }
        try modelContext.save()
    }

    func deleteCategory(id: UUID) throws {
        let descriptor = FetchDescriptor<CategoryEntity>(predicate: #Predicate { $0.id == id })
        for entity in try modelContext.fetch(descriptor) { modelContext.delete(entity) }
        try modelContext.save()
    }

    // MARK: - Completion

    /// Idempotently set the status of a task on a day. Uses the (taskID, day)
    /// natural key so repeated calls / multi-device edits never create duplicates.
    func setStatus(_ status: CompletionStatus, taskID: UUID, day: CalendarDay, completedSubtaskIDs: Set<UUID> = [], now: Date) throws {
        let y = day.year, m = day.month, d = day.day
        let descriptor = FetchDescriptor<CompletionEntity>(
            predicate: #Predicate { $0.taskID == taskID && $0.dayYear == y && $0.dayMonth == m && $0.dayDay == d }
        )
        let matches = try modelContext.fetch(descriptor)
        // Collapse any accidental duplicates to a single record.
        if let keep = matches.first {
            for extra in matches.dropFirst() { modelContext.delete(extra) }
            keep.apply(CompletionRecord(id: keep.id, taskID: taskID, day: day, status: status,
                                        completedSubtaskIDs: completedSubtaskIDs, updatedAt: now))
        } else {
            modelContext.insert(CompletionEntity(record: CompletionRecord(
                taskID: taskID, day: day, status: status,
                completedSubtaskIDs: completedSubtaskIDs, updatedAt: now)))
        }
        try modelContext.save()
    }

    func clearStatus(taskID: UUID, day: CalendarDay) throws {
        let y = day.year, m = day.month, d = day.day
        let descriptor = FetchDescriptor<CompletionEntity>(
            predicate: #Predicate { $0.taskID == taskID && $0.dayYear == y && $0.dayMonth == m && $0.dayDay == d }
        )
        for entity in try modelContext.fetch(descriptor) { modelContext.delete(entity) }
        try modelContext.save()
    }

    func completions(from: CalendarDay, through: CalendarDay) throws -> [CompletionRecord] {
        // Fetch all and filter in-memory by CalendarDay comparison (ranges over the
        // (y,m,d) tuple are awkward as a predicate; volume is small for a personal app).
        let all = try modelContext.fetch(FetchDescriptor<CompletionEntity>()).map(\.record)
        let filtered = all.filter { $0.day >= from && $0.day <= through }
        return resolver.dedupeCompletions(filtered)
    }

    func statusMap(on day: CalendarDay) throws -> [UUID: CompletionStatus] {
        let records = try completions(from: day, through: day)
        return Dictionary(records.map { ($0.taskID, $0.status) }, uniquingKeysWith: { _, new in new })
    }

    // MARK: - Hydration

    func addHydration(_ amount: Double, unit: MeasurementUnit, day: CalendarDay, at timestamp: Date) throws {
        guard amount > 0 else { return }   // never allow negative/zero to persist
        let ml = amount * unit.toMilliliters
        modelContext.insert(HydrationEntryEntity(day: day, milliliters: ml, timestamp: timestamp))
        try modelContext.save()
    }

    func removeHydrationEntry(id: UUID) throws {
        let descriptor = FetchDescriptor<HydrationEntryEntity>(predicate: #Predicate { $0.id == id })
        for entity in try modelContext.fetch(descriptor) { modelContext.delete(entity) }
        try modelContext.save()
    }

    func hydrationDay(_ day: CalendarDay) throws -> HydrationDay {
        let y = day.year, m = day.month, d = day.day
        let descriptor = FetchDescriptor<HydrationEntryEntity>(
            predicate: #Predicate { $0.dayYear == y && $0.dayMonth == m && $0.dayDay == d }
        )
        let entries = try modelContext.fetch(descriptor).map(\.entry).sorted { $0.timestamp < $1.timestamp }
        return HydrationDay(day: day, entries: entries)
    }

    func hydrationHistory(from: CalendarDay, through: CalendarDay) throws -> [HydrationDay] {
        let all = try modelContext.fetch(FetchDescriptor<HydrationEntryEntity>())
        let grouped = Dictionary(grouping: all) { $0.day }
        return grouped
            .filter { $0.key >= from && $0.key <= through }
            .map { HydrationDay(day: $0.key, entries: $0.value.map(\.entry).sorted { $0.timestamp < $1.timestamp }) }
            .sorted { $0.day < $1.day }
    }

    // MARK: - Seed / reset / export / import

    var isEmpty: Bool {
        ((try? modelContext.fetchCount(FetchDescriptor<TaskEntity>())) ?? 0) == 0
    }

    func installDefaultRoutine(referenceDay: CalendarDay) throws {
        let bundle = DefaultRoutine.build(referenceDay: referenceDay)
        for category in bundle.categories { modelContext.insert(CategoryEntity(category: category)) }
        for task in bundle.tasks { modelContext.insert(TaskEntity(model: task)) }
        try modelContext.save()
    }

    func exportArchive(now: Date, hydrationGoal: HydrationGoal) throws -> DataArchive {
        DataArchive(
            exportedAt: now,
            categories: try allCategories(),
            tasks: try allTasks(includeArchived: true),
            completions: try modelContext.fetch(FetchDescriptor<CompletionEntity>()).map(\.record),
            hydrationDays: try modelContext.fetch(FetchDescriptor<HydrationEntryEntity>())
                .reduce(into: [CalendarDay: [HydrationDay.Entry]]()) { acc, e in acc[e.day, default: []].append(e.entry) }
                .map { HydrationDay(day: $0.key, entries: $0.value) },
            hydrationGoal: hydrationGoal
        )
    }

    /// Replace-or-merge import. Merges by id/natural-key so re-importing is safe.
    func importArchive(_ archive: DataArchive) throws {
        for category in archive.categories { try upsert(category) }
        for task in archive.tasks { try upsert(task) }
        for record in resolver.dedupeCompletions(archive.completions) {
            try setStatus(record.status, taskID: record.taskID, day: record.day,
                          completedSubtaskIDs: record.completedSubtaskIDs, updatedAt: record.updatedAt)
        }
        for hDay in resolver.mergeHydration(archive.hydrationDays) {
            for entry in hDay.entries {
                // Skip entries that already exist (idempotent import).
                let eid = entry.id
                let existing = try modelContext.fetch(FetchDescriptor<HydrationEntryEntity>(predicate: #Predicate { $0.id == eid }))
                if existing.isEmpty {
                    modelContext.insert(HydrationEntryEntity(id: entry.id, day: hDay.day,
                                                             milliliters: entry.milliliters, timestamp: entry.timestamp))
                }
            }
        }
        try modelContext.save()
    }

    /// Delete everything (used by "Reset template" and "Delete all data").
    func deleteAllData() throws {
        try modelContext.delete(model: TaskEntity.self)
        try modelContext.delete(model: CompletionEntity.self)
        try modelContext.delete(model: HydrationEntryEntity.self)
        try modelContext.delete(model: CategoryEntity.self)
        try modelContext.save()
    }

    // Overload used by importArchive to carry a specific updatedAt.
    private func setStatus(_ status: CompletionStatus, taskID: UUID, day: CalendarDay,
                           completedSubtaskIDs: Set<UUID>, updatedAt: Date) throws {
        try setStatus(status, taskID: taskID, day: day, completedSubtaskIDs: completedSubtaskIDs, now: updatedAt)
    }
}

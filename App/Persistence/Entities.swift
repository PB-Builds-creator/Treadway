import Foundation
import SwiftData
import CairnCore

// SwiftData entities. Design constraints for CloudKit private-DB mirroring:
//   • every stored property has a default value,
//   • no `@Attribute(.unique)` (uniqueness enforced in `Store` via UUID / natural key),
//   • no required relationships (we reference by id and fetch — see ARCHITECTURE.md
//     "Decision 4"), which keeps recurring tasks from being materialized per-day.
//
// Complex value types from CairnCore are stored as JSON `Data` blobs with computed
// accessors, so the schema stays flat and CloudKit-friendly. All decoding is
// failure-tolerant (never force-unwraps).

private let jsonEncoder: JSONEncoder = {
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
}()
private let jsonDecoder: JSONDecoder = {
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
}()

@Model
final class TaskEntity {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var categoryID: UUID?
    var symbolName: String = "circle"
    var priorityRaw: Int = Priority.normal.rawValue
    var groupRaw: String = TaskGroup.anytime.rawValue
    var sortIndex: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()
    var estimatedMinutes: Int?

    // JSON-encoded CairnCore value types.
    var timingData: Data = Data()
    var scheduleData: Data = Data()
    var remindersData: Data = Data()
    var subtasksData: Data = Data()
    var goalData: Data?

    init(model: TaskModel) {
        apply(model)
    }

    func apply(_ model: TaskModel) {
        id = model.id
        title = model.title
        notes = model.notes
        categoryID = model.categoryID
        symbolName = model.symbolName
        priorityRaw = model.priority.rawValue
        groupRaw = model.group.rawValue
        sortIndex = model.sortIndex
        isArchived = model.isArchived
        createdAt = model.createdAt
        estimatedMinutes = model.estimatedMinutes
        timingData = (try? jsonEncoder.encode(model.timing)) ?? Data()
        scheduleData = (try? jsonEncoder.encode(model.schedule)) ?? Data()
        remindersData = (try? jsonEncoder.encode(model.reminders)) ?? Data()
        subtasksData = (try? jsonEncoder.encode(model.subtasks)) ?? Data()
        goalData = model.goal.flatMap { try? jsonEncoder.encode($0) }
    }

    /// Convert back to the pure-domain value type. Falls back to safe defaults so a
    /// corrupt blob degrades gracefully instead of crashing.
    var model: TaskModel {
        let timing = (try? jsonDecoder.decode(TaskTiming.self, from: timingData)) ?? .anytime
        let fallbackSchedule = RecurrenceEngine.Schedule(
            rule: .daily,
            startDay: MountainTime.day(for: createdAt)
        )
        let schedule = (try? jsonDecoder.decode(RecurrenceEngine.Schedule.self, from: scheduleData)) ?? fallbackSchedule
        let reminders = (try? jsonDecoder.decode([ReminderRule].self, from: remindersData)) ?? []
        let subtasks = (try? jsonDecoder.decode([Subtask].self, from: subtasksData)) ?? []
        let goal = goalData.flatMap { try? jsonDecoder.decode(MeasurableGoal.self, from: $0) }
        return TaskModel(
            id: id,
            title: title,
            notes: notes,
            categoryID: categoryID,
            symbolName: symbolName,
            priority: Priority(rawValue: priorityRaw) ?? .normal,
            timing: timing,
            group: TaskGroup(rawValue: groupRaw) ?? .anytime,
            schedule: schedule,
            reminders: reminders,
            subtasks: subtasks,
            goal: goal,
            estimatedMinutes: estimatedMinutes,
            isArchived: isArchived,
            sortIndex: sortIndex,
            createdAt: createdAt
        )
    }
}

@Model
final class CompletionEntity {
    var id: UUID = UUID()
    var taskID: UUID = UUID()
    var dayYear: Int = 0
    var dayMonth: Int = 0
    var dayDay: Int = 0
    var statusRaw: String = CompletionStatus.completed.rawValue
    var completedSubtaskIDsData: Data = Data()
    var updatedAt: Date = Date()

    init(record: CompletionRecord) { apply(record) }

    func apply(_ record: CompletionRecord) {
        id = record.id
        taskID = record.taskID
        dayYear = record.day.year
        dayMonth = record.day.month
        dayDay = record.day.day
        statusRaw = record.status.rawValue
        completedSubtaskIDsData = (try? jsonEncoder.encode(Array(record.completedSubtaskIDs))) ?? Data()
        updatedAt = record.updatedAt
    }

    var record: CompletionRecord {
        let ids = (try? jsonDecoder.decode([UUID].self, from: completedSubtaskIDsData)) ?? []
        return CompletionRecord(
            id: id,
            taskID: taskID,
            day: CalendarDay(year: dayYear, month: dayMonth, day: dayDay),
            status: CompletionStatus(rawValue: statusRaw) ?? .completed,
            completedSubtaskIDs: Set(ids),
            updatedAt: updatedAt
        )
    }

    var naturalKey: String { "\(taskID.uuidString)#\(dayYear)-\(dayMonth)-\(dayDay)" }
}

@Model
final class HydrationEntryEntity {
    var id: UUID = UUID()
    var dayYear: Int = 0
    var dayMonth: Int = 0
    var dayDay: Int = 0
    var milliliters: Double = 0
    var timestamp: Date = Date()

    init(id: UUID = UUID(), day: CalendarDay, milliliters: Double, timestamp: Date) {
        self.id = id
        self.dayYear = day.year
        self.dayMonth = day.month
        self.dayDay = day.day
        self.milliliters = milliliters
        self.timestamp = timestamp
    }

    var day: CalendarDay { CalendarDay(year: dayYear, month: dayMonth, day: dayDay) }
    var entry: HydrationDay.Entry { .init(id: id, milliliters: milliliters, timestamp: timestamp) }
}

@Model
final class CategoryEntity {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "folder"
    var sortIndex: Int = 0

    init(category: TaskCategory) {
        id = category.id
        name = category.name
        symbolName = category.symbolName
        sortIndex = category.sortIndex
    }

    var category: TaskCategory { TaskCategory(id: id, name: name, symbolName: symbolName, sortIndex: sortIndex) }
}

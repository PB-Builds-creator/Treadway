import Foundation

/// Status of a task on a particular day.
public enum CompletionStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case completed
    case skipped
    case partial      // used by tasks like the Asia Trading Session
}

public enum Priority: Int, Codable, Sendable, CaseIterable, Comparable {
    case low = 0
    case normal = 1
    case high = 2

    public static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}

/// Logical time-of-day grouping used by the Today screen. Derived from a task's
/// timing, but overridable by the user.
public enum TaskGroup: String, Codable, Sendable, CaseIterable {
    case morning
    case daytime
    case evening
    case beforeBed
    case trading
    case anytime

    public var title: String {
        switch self {
        case .morning: return "Morning"
        case .daytime: return "Daytime"
        case .evening: return "Evening"
        case .beforeBed: return "Before Bed"
        case .trading: return "Trading"
        case .anytime: return "Anytime"
        }
    }

    /// Display order on the Today screen.
    public var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .daytime: return 1
        case .trading: return 2
        case .evening: return 3
        case .beforeBed: return 4
        case .anytime: return 5
        }
    }

    /// Infer a sensible default group from an anchor time.
    public static func inferred(from timing: TaskTiming) -> TaskGroup {
        guard let time = timing.anchorTime else { return .anytime }
        switch time.hour {
        case 0..<11: return .morning
        case 11..<17: return .daytime
        case 17..<21: return .evening
        default: return .beforeBed
        }
    }
}

/// A subtask (e.g. the checklist inside the Asia Trading Session).
public struct Subtask: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var sortIndex: Int

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, sortIndex: Int = 0) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.sortIndex = sortIndex
    }
}

/// A measurable goal attached to a task (currently used by hydration, but generic).
public struct MeasurableGoal: Hashable, Codable, Sendable {
    public var target: Double
    public var unit: MeasurementUnit

    public init(target: Double, unit: MeasurementUnit) {
        self.target = target
        self.unit = unit
    }
}

/// Volume units. Ounces are the default; the model is unit-aware so milliliters
/// (or others) can be added later without a data migration.
public enum MeasurementUnit: String, Codable, Sendable {
    case fluidOunces
    case milliliters

    public var abbreviation: String {
        switch self {
        case .fluidOunces: return "oz"
        case .milliliters: return "mL"
        }
    }

    /// Conversion factor to milliliters (the canonical storage unit).
    public var toMilliliters: Double {
        switch self {
        case .fluidOunces: return 29.5735
        case .milliliters: return 1
        }
    }
}

/// The pure-domain representation of a task. The SwiftData persistence layer maps
/// its `@Model` entities to and from this value type; all logic operates on this.
public struct TaskModel: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var notes: String
    public var categoryID: UUID?
    public var symbolName: String              // SF Symbol
    public var priority: Priority
    public var timing: TaskTiming
    public var group: TaskGroup
    public var schedule: RecurrenceEngine.Schedule
    public var reminders: [ReminderRule]
    public var subtasks: [Subtask]
    public var goal: MeasurableGoal?           // non-nil => measurable task (hydration)
    public var estimatedMinutes: Int?
    public var isArchived: Bool
    public var sortIndex: Int
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        categoryID: UUID? = nil,
        symbolName: String = "circle",
        priority: Priority = .normal,
        timing: TaskTiming = .anytime,
        group: TaskGroup? = nil,
        schedule: RecurrenceEngine.Schedule,
        reminders: [ReminderRule] = [],
        subtasks: [Subtask] = [],
        goal: MeasurableGoal? = nil,
        estimatedMinutes: Int? = nil,
        isArchived: Bool = false,
        sortIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.categoryID = categoryID
        self.symbolName = symbolName
        self.priority = priority
        self.timing = timing
        self.group = group ?? TaskGroup.inferred(from: timing)
        self.schedule = schedule
        self.reminders = reminders
        self.subtasks = subtasks
        self.goal = goal
        self.estimatedMinutes = estimatedMinutes
        self.isArchived = isArchived
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    public var isMeasurable: Bool { goal != nil }
}

/// A user-defined category (e.g. "Faith", "Health", "Trading").
public struct TaskCategory: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var sortIndex: Int

    public init(id: UUID = UUID(), name: String, symbolName: String = "folder", sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.sortIndex = sortIndex
    }
}

/// A completion record for one task on one Mountain-Time day. `taskID + day` is a
/// stable natural key that de-duplicates records during CloudKit sync so two
/// devices completing the same task on the same day never create duplicates.
public struct CompletionRecord: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var taskID: UUID
    public var day: CalendarDay
    public var status: CompletionStatus
    public var completedSubtaskIDs: Set<UUID>
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        day: CalendarDay,
        status: CompletionStatus = .completed,
        completedSubtaskIDs: Set<UUID> = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.day = day
        self.status = status
        self.completedSubtaskIDs = completedSubtaskIDs
        self.updatedAt = updatedAt
    }

    /// Deterministic de-duplication key used by the sync merge logic.
    public var naturalKey: String { "\(taskID.uuidString)#\(day.year)-\(day.month)-\(day.day)" }
}

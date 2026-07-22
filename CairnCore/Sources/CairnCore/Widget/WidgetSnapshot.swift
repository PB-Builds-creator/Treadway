import Foundation

/// A compact, Codable summary the app publishes to the shared app group after each
/// refresh, so widgets and the trading complication render real data without opening
/// the SwiftData store in the extension process.
public struct WidgetSnapshot: Codable, Sendable {
    public struct TaskLine: Codable, Sendable, Identifiable {
        public var id: UUID
        public var title: String
        public var symbolName: String
        public var timeLabel: String?
        public var isDone: Bool
        public init(id: UUID, title: String, symbolName: String, timeLabel: String?, isDone: Bool) {
            self.id = id; self.title = title; self.symbolName = symbolName
            self.timeLabel = timeLabel; self.isDone = isDone
        }
    }

    public var generatedAt: Date
    public var dayLabel: String
    public var completionFraction: Double
    public var completedCount: Int
    public var remainingCount: Int
    public var hydrationOunces: Double
    public var hydrationGoalOunces: Double
    public var nextTasks: [TaskLine]
    public var nextAsiaSessionStart: Date?
    public var asiaSessionIsLive: Bool

    public init(
        generatedAt: Date, dayLabel: String, completionFraction: Double,
        completedCount: Int, remainingCount: Int, hydrationOunces: Double,
        hydrationGoalOunces: Double, nextTasks: [TaskLine],
        nextAsiaSessionStart: Date?, asiaSessionIsLive: Bool
    ) {
        self.generatedAt = generatedAt
        self.dayLabel = dayLabel
        self.completionFraction = completionFraction
        self.completedCount = completedCount
        self.remainingCount = remainingCount
        self.hydrationOunces = hydrationOunces
        self.hydrationGoalOunces = hydrationGoalOunces
        self.nextTasks = nextTasks
        self.nextAsiaSessionStart = nextAsiaSessionStart
        self.asiaSessionIsLive = asiaSessionIsLive
    }

    public var hydrationFraction: Double {
        guard hydrationGoalOunces > 0 else { return 0 }
        return min(max(hydrationOunces / hydrationGoalOunces, 0), 1)
    }

    /// A safe empty snapshot for widget placeholders / first run.
    public static let placeholder = WidgetSnapshot(
        generatedAt: Date(), dayLabel: "Today", completionFraction: 0.4,
        completedCount: 2, remainingCount: 3, hydrationOunces: 80, hydrationGoalOunces: 200,
        nextTasks: [
            TaskLine(id: UUID(), title: "Read the Bible app", symbolName: "book", timeLabel: "9:15 PM", isDone: false),
            TaskLine(id: UUID(), title: "Take ashwagandha", symbolName: "pills", timeLabel: "9:00 PM", isDone: false)
        ],
        nextAsiaSessionStart: nil, asiaSessionIsLive: false
    )
}

/// Reads/writes `WidgetSnapshot` in the shared app group. Compiled into every target.
public enum WidgetSnapshotStore {
    public static let appGroup = "group.com.paxton.cairn"
    private static let key = "widgetSnapshot"

    public static func write(_ snapshot: WidgetSnapshot, suiteName: String = appGroup) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key)
        }
    }

    public static func read(suiteName: String = appGroup) -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

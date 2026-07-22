import WidgetKit
import SwiftUI
import AppIntents
import CairnCore

// MARK: - Completion widget (small + lock-screen circular)

struct CompletionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CairnCompletion", provider: SnapshotProvider()) { entry in
            CompletionView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Completion")
        .description("Your progress through today's tasks.")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct CompletionView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: snapshot.completionFraction) {
                Image(systemName: "checkmark")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.dayLabel).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(snapshot.completionFraction * 100))%")
                    .font(.system(size: 34, weight: .semibold)).monospacedDigit()
                ProgressView(value: snapshot.completionFraction).tint(.primary)
                Text("\(snapshot.remainingCount) remaining").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Next tasks (medium)

struct NextTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CairnNextTasks", provider: SnapshotProvider()) { entry in
            NextTasksView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Tasks")
        .description("The next few tasks on your list.")
        .supportedFamilies([.systemMedium])
    }
}

struct NextTasksView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today").font(.headline)
                Spacer()
                Text("\(Int(snapshot.completionFraction * 100))%")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            if snapshot.nextTasks.isEmpty {
                Spacer()
                Text("All done for today.").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(snapshot.nextTasks.prefix(3)) { task in
                    HStack(spacing: 8) {
                        // Interactive completion via App Intent.
                        Button(intent: CompleteTaskLineIntent(taskID: task.id.uuidString)) {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                        .buttonStyle(.plain)
                        Text(task.title).font(.subheadline).lineLimit(1)
                        Spacer()
                        if let time = task.timeLabel {
                            Text(time).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Hydration (small + medium, interactive quick-add)

struct HydrationWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CairnHydration", provider: SnapshotProvider()) { entry in
            HydrationView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hydration")
        .description("Water progress with quick add.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline])
    }
}

struct HydrationView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Water \(Int(snapshot.hydrationOunces))/\(Int(snapshot.hydrationGoalOunces)) oz")
        default:
            VStack(alignment: .leading, spacing: 8) {
                Label("\(Int(snapshot.hydrationOunces)) / \(Int(snapshot.hydrationGoalOunces)) oz", systemImage: "drop.fill")
                    .font(.subheadline.weight(.medium))
                ProgressView(value: snapshot.hydrationFraction).tint(.primary)
                HStack(spacing: 6) {
                    ForEach([8, 16, 24], id: \.self) { amount in
                        Button(intent: AddWaterIntent(ounces: Double(amount))) {
                            Text("+\(amount)").font(.caption.weight(.medium)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

// MARK: - Trading session

struct TradingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CairnTrading", provider: SnapshotProvider()) { entry in
            TradingView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Asia Session")
        .description("Your next Asia trading session.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}

struct TradingView: View {
    let snapshot: WidgetSnapshot
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Asia Session", systemImage: "chart.line.uptrend.xyaxis").font(.caption.weight(.semibold))
            Spacer()
            if snapshot.asiaSessionIsLive {
                Text("Live now").font(.title3.weight(.semibold))
                Text("Ends 8:00 PM MT").font(.caption).foregroundStyle(.secondary)
            } else if let start = snapshot.nextAsiaSessionStart {
                Text(start, format: .dateTime.weekday().hour().minute()).font(.subheadline.weight(.medium))
                Text("6:00–8:00 PM MT").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("No session scheduled").font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Interactive complete-by-id intent (used by the medium widget button)

struct CompleteTaskLineIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Task"
    @Parameter(title: "Task ID") var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else { return .result() }
        let store = IntentSupport.makeStore()
        // Toggle: if already completed today, clear it; else complete.
        let map = try await store.statusMap(on: IntentSupport.currentDay)
        if map[uuid] == .completed {
            try await store.clearStatus(taskID: uuid, day: IntentSupport.currentDay)
        } else {
            try await store.setStatus(.completed, taskID: uuid, day: IntentSupport.currentDay, now: Date())
        }
        WidgetRefresher.reloadAll()
        return .result()
    }
}

import WidgetKit
import SwiftUI
import CairnCore

@main
struct CairnWidgetBundle: WidgetBundle {
    var body: some Widget {
        CompletionWidget()
        NextTasksWidget()
        HydrationWidget()
        TradingWidget()
    }
}

// MARK: - Timeline provider (reads the shared snapshot)

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .placeholder)
    }
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshotStore.read() ?? .placeholder))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? .placeholder
        let entry = SnapshotEntry(date: Date(), snapshot: snapshot)
        // Refresh roughly hourly; app also reloads timelines on data changes.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

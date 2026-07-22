import Foundation
import AppIntents
import CairnCore
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Complete task

struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Task"
    static let description = IntentDescription("Mark one of today's tasks as done.")

    @Parameter(title: "Task") var task: TaskAppEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IntentSupport.makeStore()
        try await store.setStatus(.completed, taskID: task.id, day: IntentSupport.currentDay, now: Date())
        WidgetRefresher.reloadAll()
        return .result(dialog: "Marked \(task.title) complete.")
    }
}

// MARK: - Add water

struct AddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Water"
    static let description = IntentDescription("Log water toward your daily hydration goal.")

    @Parameter(title: "Ounces", default: 16) var ounces: Double

    init() {}
    init(ounces: Double) { self.ounces = ounces }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard ounces > 0 else { return .result(dialog: "Enter an amount greater than zero.") }
        let store = IntentSupport.makeStore()
        try await store.addHydration(ounces, unit: .fluidOunces, day: IntentSupport.currentDay, at: Date())
        WidgetRefresher.reloadAll()
        return .result(dialog: "Added \(Int(ounces)) oz of water.")
    }
}

// MARK: - Add a new task

struct AddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Task"
    static let description = IntentDescription("Create a new daily task in Cairn.")

    @Parameter(title: "Title") var title: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .result(dialog: "Please provide a title.") }
        let store = IntentSupport.makeStore()
        let day = IntentSupport.currentDay
        let task = TaskModel(title: trimmed, schedule: .init(rule: .daily, startDay: day))
        try await store.upsert(task)
        WidgetRefresher.reloadAll()
        return .result(dialog: "Added “\(trimmed)”.")
    }
}

// MARK: - Show today (opens the app)

struct ShowTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Today's Tasks"
    static let openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}

// MARK: - Start Asia trading session

struct StartAsiaSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Asia Trading Session"
    static let description = IntentDescription("Mark the Asia trading session in progress for today.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IntentSupport.makeStore()
        let tasks = try await store.allTasks()
        guard let session = tasks.first(where: { $0.group == .trading || $0.title.localizedCaseInsensitiveContains("asia") }) else {
            return .result(dialog: "No trading session task found.")
        }
        try await store.setStatus(.partial, taskID: session.id, day: IntentSupport.currentDay, now: Date())
        WidgetRefresher.reloadAll()
        return .result(dialog: "Asia session started. Good luck.")
    }
}

// MARK: - Open MyFitnessPal / Bible

struct OpenMyFitnessPalIntent: AppIntent {
    static let title: LocalizedStringResource = "Open MyFitnessPal"
    static let openAppWhenRun = false
    @MainActor
    func perform() async throws -> some IntentResult {
        let scheme = SharedDefaults.string("mfpURL") ?? "myfitnesspal://"
        openExternal(scheme, fallback: "https://www.myfitnesspal.com")
        return .result()
    }
}

struct OpenBibleIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Bible App"
    static let openAppWhenRun = false
    @MainActor
    func perform() async throws -> some IntentResult {
        let scheme = SharedDefaults.string("bibleURL") ?? "youversion://"
        openExternal(scheme, fallback: "https://www.bible.com")
        return .result()
    }
}

@MainActor
private func openExternal(_ scheme: String, fallback: String) {
    let url = URL(string: scheme) ?? URL(string: fallback)
    guard let url else { return }
    #if canImport(UIKit)
    UIApplication.shared.open(url, options: [:]) { ok in
        if !ok, let web = URL(string: fallback) { UIApplication.shared.open(web) }
    }
    #elseif canImport(AppKit)
    if !NSWorkspace.shared.open(url), let web = URL(string: fallback) { NSWorkspace.shared.open(web) }
    #endif
}

// MARK: - Shared defaults + widget refresh helpers

enum SharedDefaults {
    static var suite: UserDefaults? { UserDefaults(suiteName: "group.com.paxton.cairn") }
    static func string(_ key: String) -> String? { suite?.string(forKey: key) }
}

enum WidgetRefresher {
    static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

// MARK: - App Shortcuts (Spotlight / Siri / Action button)

struct CairnShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: ShowTodayIntent(), phrases: [
            "Show my \(.applicationName) tasks",
            "Open \(.applicationName) today"
        ], shortTitle: "Today", systemImageName: "sun.max")

        AppShortcut(intent: AddWaterIntent(), phrases: [
            "Add water in \(.applicationName)",
            "Log water in \(.applicationName)"
        ], shortTitle: "Add Water", systemImageName: "drop")

        AppShortcut(intent: AddTaskIntent(), phrases: [
            "Add a task in \(.applicationName)"
        ], shortTitle: "Add Task", systemImageName: "plus")

        AppShortcut(intent: StartAsiaSessionIntent(), phrases: [
            "Start my \(.applicationName) trading session"
        ], shortTitle: "Start Session", systemImageName: "chart.line.uptrend.xyaxis")
    }
}

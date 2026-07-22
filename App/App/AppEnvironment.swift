import Foundation
import SwiftUI
import CairnCore

/// The app-wide coordinator injected into the view tree. Owns the `Store`, clock,
/// settings, and the managers, and exposes async intents the UI calls. Keeps views
/// thin: they read published snapshots and call methods here.
@MainActor
@Observable
final class AppEnvironment {
    let store: Store
    let settings: AppSettings
    let clock: Clock
    let notifications: NotificationManager
    let lock: AppLockManager
    let deepLinker = DeepLinker()

    private let todayBuilder = TodayBuilder()
    private let streakCalc = StreakCalculator()

    // Published state consumed by screens.
    private(set) var todaySnapshot: TodayBuilder.Snapshot?
    private(set) var hydrationDay: HydrationDay?
    private(set) var categories: [TaskCategory] = []
    private(set) var loadError: String?

    /// The current Mountain-Time day. Recomputed on refresh / midnight crossing.
    var currentDay: CalendarDay { MountainTime.day(for: clock.now) }

    init(store: Store, settings: AppSettings, clock: Clock = SystemClock()) {
        self.store = store
        self.settings = settings
        self.clock = clock
        self.notifications = NotificationManager()
        self.lock = AppLockManager(settings: settings)
    }

    // MARK: - Loading

    func refresh() async {
        do {
            let day = currentDay
            let tasks = try await store.allTasks()
            let statusMap = try await store.statusMap(on: day)
            categories = try await store.allCategories()
            todaySnapshot = todayBuilder.snapshot(tasks: tasks, on: day) { statusMap[$0] }
            hydrationDay = try await store.hydrationDay(day)
            loadError = nil
            publishWidgetSnapshot(tasks: tasks)
            await rescheduleNotifications(tasks: tasks)
        } catch {
            loadError = "Couldn't load your data. \(error.localizedDescription)"
        }
    }

    // MARK: - Task intents

    func toggleComplete(_ item: TodayBuilder.Item) async {
        let day = currentDay
        do {
            if item.isDone {
                try await store.clearStatus(taskID: item.task.id, day: day)
            } else {
                try await store.setStatus(.completed, taskID: item.task.id, day: day, now: clock.now)
            }
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func setStatus(_ status: CompletionStatus, taskID: UUID, completedSubtaskIDs: Set<UUID> = []) async {
        do {
            try await store.setStatus(status, taskID: taskID, day: currentDay,
                                      completedSubtaskIDs: completedSubtaskIDs, now: clock.now)
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func skipToday(taskID: UUID) async {
        do {
            try await store.setStatus(.skipped, taskID: taskID, day: currentDay, now: clock.now)
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func save(_ task: TaskModel) async {
        do { try await store.upsert(task); await refresh() }
        catch { loadError = error.localizedDescription }
    }

    /// Recurring-edit scope: "this and future occurrences". Ends the original series
    /// the day before `from` and creates a new task carrying the edits from `from`.
    func saveThisAndFuture(original: TaskModel, edited: TaskModel, from day: CalendarDay) async {
        do {
            var old = original
            let engine = RecurrenceEngine()
            var prev = day
            prev = MountainTime.day(for: MountainTime.calendar.date(byAdding: .day, value: -1, to: day.startOfDay) ?? day.startOfDay)
            old.schedule.endDay = prev
            try await store.upsert(old)

            var new = edited
            new.id = UUID()               // a new series
            new.schedule.startDay = day
            try await store.upsert(new)
            _ = engine
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    /// Recurring-edit scope: "only this occurrence". Skips `day` on the original and
    /// creates a one-time task with the edits on that day.
    func saveOnlyThis(original: TaskModel, edited: TaskModel, on day: CalendarDay) async {
        do {
            var old = original
            old.schedule.skippedDays.insert(day)
            try await store.upsert(old)

            var one = edited
            one.id = UUID()
            one.schedule = RecurrenceEngine.Schedule(rule: .oneTime(day), startDay: day)
            try await store.upsert(one)
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func duplicate(_ task: TaskModel) async {
        var copy = task
        copy.id = UUID()
        copy.title = task.title + " copy"
        await save(copy)
    }

    func delete(taskID: UUID) async {
        do { try await store.delete(taskID: taskID); await refresh() }
        catch { loadError = error.localizedDescription }
    }

    func setArchived(_ archived: Bool, taskID: UUID) async {
        do { try await store.setArchived(archived, taskID: taskID); await refresh() }
        catch { loadError = error.localizedDescription }
    }

    func reorder(_ orderedIDs: [UUID]) async {
        do { try await store.reorder(orderedIDs); await refresh() }
        catch { loadError = error.localizedDescription }
    }

    // MARK: - Hydration intents

    func addWater(_ ounces: Double) async {
        do {
            try await store.addHydration(ounces, unit: .fluidOunces, day: currentDay, at: clock.now)
            hydrationDay = try await store.hydrationDay(currentDay)
        } catch { loadError = error.localizedDescription }
    }

    func removeHydrationEntry(_ id: UUID) async {
        do {
            try await store.removeHydrationEntry(id: id)
            hydrationDay = try await store.hydrationDay(currentDay)
        } catch { loadError = error.localizedDescription }
    }

    // MARK: - Widget snapshot

    private func publishWidgetSnapshot(tasks: [TaskModel]) {
        guard let snapshot = todaySnapshot else { return }
        let hyd = hydrationDay ?? HydrationDay(day: currentDay)
        let asia = AsiaSession()
        let session = asia.nextSession(now: clock.now)

        let nextLines: [WidgetSnapshot.TaskLine] = snapshot.sections
            .flatMap(\.items)
            .prefix(4)
            .map { item in
                WidgetSnapshot.TaskLine(
                    id: item.task.id,
                    title: item.task.title,
                    symbolName: item.task.symbolName,
                    timeLabel: item.task.timing.anchorTime?.displayString,
                    isDone: item.isDone
                )
            }

        let payload = WidgetSnapshot(
            generatedAt: clock.now,
            dayLabel: dayLabel,
            completionFraction: snapshot.completionFraction,
            completedCount: snapshot.completedCount,
            remainingCount: snapshot.remainingCount,
            hydrationOunces: hyd.total(in: .fluidOunces),
            hydrationGoalOunces: settings.hydrationTargetOunces,
            nextTasks: nextLines,
            nextAsiaSessionStart: session?.start,
            asiaSessionIsLive: asia.isLive(now: clock.now)
        )
        WidgetSnapshotStore.write(payload)
    }

    private var dayLabel: String {
        let f = DateFormatter(); f.timeZone = MountainTime.timeZone; f.dateFormat = "EEE, MMM d"
        return f.string(from: clock.now)
    }

    // MARK: - Notifications

    func rescheduleNotifications(tasks: [TaskModel]) async {
        guard settings.notificationsEnabled else {
            await notifications.cancelAll()
            return
        }
        let statusMap = (try? await store.statusMap(on: currentDay)) ?? [:]
        // Snapshot the (main-actor) preferences into a Sendable value before crossing
        // into the notification actor.
        let prefs = NotificationManager.Prefs(
            notificationsEnabled: settings.notificationsEnabled,
            dailySummaryEnabled: settings.dailySummaryEnabled,
            dailySummaryTime: settings.dailySummaryTime,
            beforeBedSummaryEnabled: settings.beforeBedSummaryEnabled,
            beforeBedSummaryTime: settings.beforeBedSummaryTime
        )
        await notifications.reschedule(
            tasks: tasks,
            horizonDays: 7,
            startDay: currentDay,
            prefs: prefs,
            statusFor: { taskID, _ in statusMap[taskID] }
        )
    }

    // MARK: - Seed / data management

    func installDefaultRoutineIfNeeded() async {
        do {
            if await store.isEmpty {
                try await store.installDefaultRoutine(referenceDay: currentDay)
            }
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func exportArchive() async -> DataArchive? {
        try? await store.exportArchive(now: clock.now, hydrationGoal: settings.hydrationGoal)
    }

    func importArchive(_ archive: DataArchive) async {
        do { try await store.importArchive(archive); await refresh() }
        catch { loadError = error.localizedDescription }
    }

    func resetToTemplate() async {
        do {
            try await store.deleteAllData()
            try await store.installDefaultRoutine(referenceDay: currentDay)
            await refresh()
        } catch { loadError = error.localizedDescription }
    }

    func deleteAllData() async {
        do { try await store.deleteAllData(); await notifications.cancelAll(); await refresh() }
        catch { loadError = error.localizedDescription }
    }
}

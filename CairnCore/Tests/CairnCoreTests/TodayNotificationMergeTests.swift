import XCTest
@testable import CairnCore

final class TodayBuilderTests: XCTestCase {
    let builder = TodayBuilder()
    let today = CalendarDay(year: 2026, month: 7, day: 20) // Monday

    private func task(_ title: String, timing: TaskTiming, group: TaskGroup? = nil, rule: RecurrenceRule = .daily) -> TaskModel {
        TaskModel(title: title, timing: timing, group: group,
                  schedule: .init(rule: rule, startDay: CalendarDay(year: 2026, month: 1, day: 1)))
    }

    func testGroupsOnlyContainRelevantTasksAndAreSorted() {
        let morning = task("Stretch", timing: .at(TimeOfDay(hour: 7, minute: 0)))
        let bed = task("Pray", timing: .at(TimeOfDay(hour: 21, minute: 30)))
        let snapshot = builder.snapshot(tasks: [bed, morning], on: today) { _ in nil }
        XCTAssertEqual(snapshot.sections.count, 2)
        XCTAssertEqual(snapshot.sections.first?.group, .morning) // sorted before beforeBed
        XCTAssertEqual(snapshot.totalCount, 2)
        XCTAssertEqual(snapshot.remainingCount, 2)
    }

    func testCompletedTasksMoveToCompletedSection() {
        let a = task("A", timing: .anytime)
        let b = task("B", timing: .anytime)
        let snapshot = builder.snapshot(tasks: [a, b], on: today) { id in
            id == a.id ? .completed : nil
        }
        XCTAssertEqual(snapshot.completedCount, 1)
        XCTAssertEqual(snapshot.remainingCount, 1)
        XCTAssertEqual(snapshot.completedSections.flatMap(\.items).count, 1)
    }

    func testCompletionFractionAndSummary() {
        let a = task("A", timing: .anytime)
        let b = task("B", timing: .anytime)
        let c = task("C", timing: .anytime)
        let snapshot = builder.snapshot(tasks: [a, b, c], on: today) { id in
            id == a.id ? .completed : nil
        }
        XCTAssertEqual(snapshot.completionFraction, 1.0/3.0, accuracy: 0.001)
        XCTAssertFalse(snapshot.isAllDone)
    }

    func testAllDoneSummary() {
        let a = task("A", timing: .anytime)
        let snapshot = builder.snapshot(tasks: [a], on: today) { _ in .completed }
        XCTAssertTrue(snapshot.isAllDone)
        XCTAssertEqual(snapshot.summary, "All done for today.")
    }

    func testArchivedAndUnscheduledExcluded() {
        var archived = task("Archived", timing: .anytime)
        archived.isArchived = true
        let wrongDay = task("Weekend only", timing: .anytime, rule: .weekly(.saturday))
        let snapshot = builder.snapshot(tasks: [archived, wrongDay], on: today) { _ in nil }
        XCTAssertEqual(snapshot.totalCount, 0)
        XCTAssertEqual(snapshot.summary, "Nothing scheduled today.")
    }
}

final class NotificationPlannerTests: XCTestCase {
    let planner = NotificationPlanner()
    let day = CalendarDay(year: 2026, month: 7, day: 20)

    private func ashwagandhaTask() -> TaskModel {
        TaskModel(
            title: "Take ashwagandha",
            timing: .at(.ashwagandha),
            schedule: .init(rule: .daily, startDay: CalendarDay(year: 2026, month: 1, day: 1)),
            reminders: [ReminderRule(kind: .atTime(.ashwagandha))]
        )
    }

    func testAshwagandhaSchedulesNinePM() {
        let notes = planner.notifications(for: ashwagandhaTask(), on: day, status: nil, notificationsEnabledGlobally: true)
        XCTAssertEqual(notes.count, 1)
        let hour = MountainTime.calendar.component(.hour, from: notes[0].fireDate)
        XCTAssertEqual(hour, 21)
    }

    func testNoNotificationWhenCompleted() {
        let notes = planner.notifications(for: ashwagandhaTask(), on: day, status: .completed, notificationsEnabledGlobally: true)
        XCTAssertTrue(notes.isEmpty)
    }

    func testNoNotificationWhenSkipped() {
        let notes = planner.notifications(for: ashwagandhaTask(), on: day, status: .skipped, notificationsEnabledGlobally: true)
        XCTAssertTrue(notes.isEmpty)
    }

    func testNoNotificationWhenGloballyDisabled() {
        let notes = planner.notifications(for: ashwagandhaTask(), on: day, status: nil, notificationsEnabledGlobally: false)
        XCTAssertTrue(notes.isEmpty)
    }

    func testNoNotificationWhenArchived() {
        var t = ashwagandhaTask(); t.isArchived = true
        let notes = planner.notifications(for: t, on: day, status: nil, notificationsEnabledGlobally: true)
        XCTAssertTrue(notes.isEmpty)
    }

    func testStableIdentifierPreventsDuplicates() {
        let t = ashwagandhaTask()
        let a = planner.notifications(for: t, on: day, status: nil, notificationsEnabledGlobally: true)
        let b = planner.notifications(for: t, on: day, status: nil, notificationsEnabledGlobally: true)
        XCTAssertEqual(a.first?.id, b.first?.id) // idempotent => OS de-dupes
    }

    func testIntervalRemindersForHydration() {
        let water = TaskModel(
            title: "Drink water",
            timing: .anytime,
            schedule: .init(rule: .daily, startDay: CalendarDay(year: 2026, month: 1, day: 1)),
            reminders: [ReminderRule(kind: .interval(everyMinutes: 120,
                                                     start: TimeOfDay(hour: 8, minute: 0),
                                                     end: TimeOfDay(hour: 20, minute: 0)))],
            goal: MeasurableGoal(target: 200, unit: .fluidOunces)
        )
        let notes = planner.notifications(for: water, on: day, status: nil, notificationsEnabledGlobally: true)
        // 8:00 through 20:00 every 2h inclusive => 7 reminders.
        XCTAssertEqual(notes.count, 7)
    }
}

final class MergeResolverTests: XCTestCase {
    let resolver = MergeResolver()
    let day = CalendarDay(year: 2026, month: 7, day: 20)
    let taskID = UUID()

    func testDuplicateCompletionsCollapseToLatest() {
        let older = CompletionRecord(taskID: taskID, day: day, status: .completed,
                                     updatedAt: Date(timeIntervalSince1970: 100))
        let newer = CompletionRecord(taskID: taskID, day: day, status: .skipped,
                                     updatedAt: Date(timeIntervalSince1970: 200))
        let merged = resolver.dedupeCompletions([older, newer])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.status, .skipped) // newer wins
    }

    func testMergeOrderIndependent() {
        let a = CompletionRecord(taskID: taskID, day: day, status: .completed, updatedAt: Date(timeIntervalSince1970: 100))
        let b = CompletionRecord(taskID: taskID, day: day, status: .skipped, updatedAt: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(resolver.dedupeCompletions([a, b]), resolver.dedupeCompletions([b, a]))
    }

    func testHydrationMergeUnionsEntriesIdempotently() {
        let ts = Date(timeIntervalSince1970: 1000)
        let entry = HydrationDay.Entry(id: UUID(), milliliters: 100, timestamp: ts)
        let d1 = HydrationDay(day: day, entries: [entry])
        let d2 = HydrationDay(day: day, entries: [entry]) // same entry id from other device
        let merged = resolver.mergeHydration([d1, d2])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.total(in: .milliliters), 100) // not double-counted
    }
}

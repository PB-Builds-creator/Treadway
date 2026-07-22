import XCTest
@testable import CairnCore

final class ArchiveSeedTests: XCTestCase {

    func testDefaultRoutineHasSevenTasks() {
        let bundle = DefaultRoutine.build(referenceDay: CalendarDay(year: 2026, month: 7, day: 20))
        XCTAssertEqual(bundle.tasks.count, 7)
        XCTAssertEqual(bundle.hydrationGoal.target, 200)
        XCTAssertEqual(bundle.hydrationGoal.unit, .fluidOunces)
    }

    func testAsiaSessionSeededSunThroughThu() {
        let bundle = DefaultRoutine.build(referenceDay: CalendarDay(year: 2026, month: 7, day: 20))
        guard let asia = bundle.tasks.first(where: { $0.title == "Asia Trading Session" }) else {
            return XCTFail("Asia session missing")
        }
        if case .weekdays(let days) = asia.schedule.rule {
            XCTAssertEqual(days, Weekday.sundayThroughThursday)
        } else {
            XCTFail("Asia session should be a weekdays rule")
        }
        XCTAssertEqual(asia.subtasks.count, AsiaSession.defaultSubtasks.count)
        if case .window(let start, let end) = asia.timing {
            XCTAssertEqual(start, .asiaSessionStart)
            XCTAssertEqual(end, .asiaSessionEnd)
        } else {
            XCTFail("Asia session should be a window")
        }
    }

    func testAshwagandhaSeededAtNinePM() {
        let bundle = DefaultRoutine.build(referenceDay: CalendarDay(year: 2026, month: 7, day: 20))
        guard let ash = bundle.tasks.first(where: { $0.title == "Take ashwagandha" }) else {
            return XCTFail("Ashwagandha missing")
        }
        XCTAssertEqual(ash.timing, .at(.ashwagandha))
        XCTAssertEqual(ash.reminders.count, 1)
    }

    func testWaterTaskIsMeasurable() {
        let bundle = DefaultRoutine.build(referenceDay: CalendarDay(year: 2026, month: 7, day: 20))
        let water = bundle.tasks.first { $0.title.contains("water") }
        XCTAssertTrue(water?.isMeasurable ?? false)
    }

    func testArchiveRoundTrip() throws {
        let bundle = DefaultRoutine.build(referenceDay: CalendarDay(year: 2026, month: 7, day: 20))
        let archive = DataArchive(
            exportedAt: Date(timeIntervalSince1970: 0),
            categories: bundle.categories,
            tasks: bundle.tasks,
            completions: [CompletionRecord(taskID: bundle.tasks[0].id, day: CalendarDay(year: 2026, month: 7, day: 20))],
            hydrationDays: [],
            hydrationGoal: bundle.hydrationGoal
        )
        let data = try archive.encoded()
        let restored = try DataArchive.decoded(from: data)
        XCTAssertEqual(restored.tasks.count, archive.tasks.count)
        XCTAssertEqual(restored.tasks.first?.id, archive.tasks.first?.id)
        XCTAssertEqual(restored.categories, archive.categories)
        XCTAssertEqual(restored.timeZoneIdentifier, "America/Denver")
    }

    func testArchiveRejectsFutureVersion() throws {
        var archive = DataArchive(exportedAt: Date(), categories: [], tasks: [], completions: [], hydrationDays: [], hydrationGoal: .default)
        archive.version = 999
        let data = try archive.encoded()
        XCTAssertThrowsError(try DataArchive.decoded(from: data))
    }
}

final class AsiaSessionTests: XCTestCase {
    let session = AsiaSession()

    func testNextSessionFromFridayIsSunday() {
        // Friday 2026-07-24 09:00 MT => next session Sunday 2026-07-26 18:00.
        let now = FixedClock(mountain: 2026, month: 7, day: 24, hour: 9).now
        let next = session.nextSession(now: now)
        XCTAssertNotNil(next)
        XCTAssertEqual(MountainTime.day(for: next!.start), CalendarDay(year: 2026, month: 7, day: 26))
        XCTAssertEqual(MountainTime.calendar.component(.hour, from: next!.start), 18)
    }

    func testLiveDuringSession() {
        let during = FixedClock(mountain: 2026, month: 7, day: 20, hour: 19).now // Mon 7 PM
        XCTAssertTrue(session.isLive(now: during))
        let before = FixedClock(mountain: 2026, month: 7, day: 20, hour: 17).now // Mon 5 PM
        XCTAssertFalse(session.isLive(now: before))
    }

    func testNoSessionSaturdayReturnsSunday() {
        let sat = FixedClock(mountain: 2026, month: 7, day: 25, hour: 19).now
        let next = session.nextSession(now: sat)
        XCTAssertEqual(next?.start.map { MountainTime.day(for: $0) }, CalendarDay(year: 2026, month: 7, day: 26))
    }
}

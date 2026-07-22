import XCTest
@testable import CairnCore

final class RecurrenceTests: XCTestCase {
    let engine = RecurrenceEngine()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay {
        CalendarDay(year: y, month: m, day: d)
    }

    private func schedule(_ rule: RecurrenceRule, start: CalendarDay) -> RecurrenceEngine.Schedule {
        RecurrenceEngine.Schedule(rule: rule, startDay: start)
    }

    func testDailyRecurrenceOccursEveryDay() {
        let s = schedule(.daily, start: day(2026, 1, 1))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 1)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 2)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 6, 15)))
    }

    func testDailyDoesNotOccurBeforeStart() {
        let s = schedule(.daily, start: day(2026, 1, 10))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 9)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 10)))
    }

    func testWeekdayRecurrenceSunThroughThu() {
        // Asia Trading Session: Sun–Thu only, never Fri/Sat.
        let s = schedule(.weekdays(Weekday.sundayThroughThursday), start: day(2026, 7, 1))
        // 2026-07-19 is a Sunday.
        XCTAssertEqual(day(2026, 7, 19).weekday, .sunday)
        XCTAssertTrue(engine.occurs(s, on: day(2026, 7, 19)))  // Sun
        XCTAssertTrue(engine.occurs(s, on: day(2026, 7, 20)))  // Mon
        XCTAssertTrue(engine.occurs(s, on: day(2026, 7, 23)))  // Thu
        XCTAssertFalse(engine.occurs(s, on: day(2026, 7, 24))) // Fri
        XCTAssertFalse(engine.occurs(s, on: day(2026, 7, 25))) // Sat
    }

    func testWeeklyRecurrence() {
        let s = schedule(.weekly(.wednesday), start: day(2026, 1, 1))
        // 2026-01-07 is a Wednesday.
        XCTAssertEqual(day(2026, 1, 7).weekday, .wednesday)
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 7)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 8)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 14)))
    }

    func testMonthlyRecurrenceBasic() {
        let s = schedule(.monthly(day: 15), start: day(2026, 1, 1))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 15)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 2, 15)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 2, 14)))
    }

    func testMonthlyClampsToShortMonth() {
        // "31st" should land on the last day of shorter months.
        let s = schedule(.monthly(day: 31), start: day(2026, 1, 1))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 31)))
        // Feb 2026 has 28 days => clamps to Feb 28.
        XCTAssertTrue(engine.occurs(s, on: day(2026, 2, 28)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 2, 27)))
        // April has 30 days => clamps to Apr 30.
        XCTAssertTrue(engine.occurs(s, on: day(2026, 4, 30)))
    }

    func testMonthlyClampLeapYear() {
        // 2028 is a leap year => Feb 29 exists; "31st" clamps to 29.
        let s = schedule(.monthly(day: 31), start: day(2028, 1, 1))
        XCTAssertTrue(engine.occurs(s, on: day(2028, 2, 29)))
        XCTAssertFalse(engine.occurs(s, on: day(2028, 2, 28)))
    }

    func testEveryNDays() {
        let anchor = day(2026, 1, 1)
        let s = schedule(.everyNDays(interval: 3, anchor: anchor), start: anchor)
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 1)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 2)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 3)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 4)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 7)))
    }

    func testEveryNDaysAcrossMonthBoundary() {
        let anchor = day(2026, 1, 30)
        let s = schedule(.everyNDays(interval: 2, anchor: anchor), start: anchor)
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 30)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 2, 1)))   // +2 across month end
        XCTAssertTrue(engine.occurs(s, on: day(2026, 2, 3)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 2, 2)))
    }

    func testOneTime() {
        let s = schedule(.oneTime(day(2026, 3, 10)), start: day(2026, 1, 1))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 3, 10)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 3, 11)))
    }

    func testEndDateExcludesLaterDays() {
        var s = schedule(.daily, start: day(2026, 1, 1))
        s.endDay = day(2026, 1, 5)
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 5)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 6)))
    }

    func testPauseSuppressesOccurrence() {
        var s = schedule(.daily, start: day(2026, 1, 1))
        s.isPaused = true
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 2)))
    }

    func testSkipForToday() {
        var s = schedule(.daily, start: day(2026, 1, 1))
        s.skippedDays = [day(2026, 1, 3)]
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 2)))
        XCTAssertFalse(engine.occurs(s, on: day(2026, 1, 3)))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 1, 4)))
    }

    func testNextOccurrenceSkipsToValidWeekday() {
        let s = schedule(.weekdays(Weekday.sundayThroughThursday), start: day(2026, 7, 1))
        // From Friday 2026-07-24, next session is Sunday 2026-07-26.
        let next = engine.nextOccurrence(s, onOrAfter: day(2026, 7, 24))
        XCTAssertEqual(next, day(2026, 7, 26))
        XCTAssertEqual(next?.weekday, .sunday)
    }

    func testYearBoundary() {
        let s = schedule(.daily, start: day(2026, 12, 31))
        XCTAssertTrue(engine.occurs(s, on: day(2026, 12, 31)))
        XCTAssertTrue(engine.occurs(s, on: day(2027, 1, 1)))
        XCTAssertEqual(engine.daysBetween(day(2026, 12, 31), day(2027, 1, 1)), 1)
    }
}

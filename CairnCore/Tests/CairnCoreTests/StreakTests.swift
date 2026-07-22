import XCTest
@testable import CairnCore

final class StreakTests: XCTestCase {
    let calc = StreakCalculator()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay {
        CalendarDay(year: y, month: m, day: d)
    }

    func testCurrentStreakCountsConsecutiveDays() {
        let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026, 7, 1))
        let done: Set<CalendarDay> = [day(2026, 7, 18), day(2026, 7, 19), day(2026, 7, 20)]
        let result = calc.compute(schedule: s, from: day(2026, 7, 1), through: day(2026, 7, 20)) {
            done.contains($0) ? .completed : nil
        }
        XCTAssertEqual(result.current, 3)
    }

    func testMissedDayBreaksCurrentStreak() {
        let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026, 7, 1))
        // Missed the 19th; done 18 and 20 => current streak is just the 20th.
        let done: Set<CalendarDay> = [day(2026, 7, 18), day(2026, 7, 20)]
        let result = calc.compute(schedule: s, from: day(2026, 7, 1), through: day(2026, 7, 20)) {
            done.contains($0) ? .completed : nil
        }
        XCTAssertEqual(result.current, 1)
    }

    func testLongestStreak() {
        let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026, 7, 1))
        let done: Set<CalendarDay> = [
            day(2026, 7, 1), day(2026, 7, 2), day(2026, 7, 3), day(2026, 7, 4), // 4-run
            day(2026, 7, 6),
            day(2026, 7, 10)
        ]
        let result = calc.compute(schedule: s, from: day(2026, 7, 1), through: day(2026, 7, 10)) {
            done.contains($0) ? .completed : nil
        }
        XCTAssertEqual(result.longest, 4)
    }

    func testWeekdayTaskNotPenalizedForOffDays() {
        // Sun–Thu task: completing every scheduled day yields a full streak even
        // though Friday and Saturday are skipped (not scheduled).
        let s = RecurrenceEngine.Schedule(rule: .weekdays(Weekday.sundayThroughThursday), startDay: day(2026, 7, 1))
        // 7/19 Sun ... 7/23 Thu are scheduled; 7/24 Fri & 7/25 Sat are not.
        let scheduledDone: Set<CalendarDay> = [
            day(2026, 7, 19), day(2026, 7, 20), day(2026, 7, 21), day(2026, 7, 22), day(2026, 7, 23),
            day(2026, 7, 26) // next Sunday
        ]
        let result = calc.compute(schedule: s, from: day(2026, 7, 19), through: day(2026, 7, 26)) {
            scheduledDone.contains($0) ? .completed : nil
        }
        // Fri/Sat don't break the streak.
        XCTAssertEqual(result.current, 6)
        XCTAssertEqual(result.scheduledCount, 6)
    }

    func testPartialCountsTowardStreak() {
        let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026, 7, 1))
        let result = calc.compute(schedule: s, from: day(2026, 7, 19), through: day(2026, 7, 20)) { d in
            d == day(2026, 7, 19) ? .partial : .completed
        }
        XCTAssertEqual(result.current, 2)
    }

    func testCompletionRate() {
        let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026, 7, 1))
        // 3 of 5 done.
        let done: Set<CalendarDay> = [day(2026, 7, 1), day(2026, 7, 3), day(2026, 7, 5)]
        let result = calc.compute(schedule: s, from: day(2026, 7, 1), through: day(2026, 7, 5)) {
            done.contains($0) ? .completed : nil
        }
        XCTAssertEqual(result.completionRate, 0.6, accuracy: 0.001)
    }
}

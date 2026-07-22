import XCTest
@testable import CairnCore

final class TimeZoneDSTTests: XCTestCase {

    func testTimeZoneIsDenver() {
        XCTAssertEqual(MountainTime.timeZone.identifier, "America/Denver")
        XCTAssertEqual(MountainTime.displayName, "Mountain Time")
    }

    func testAbbreviationSwitchesWithDST() {
        // Standard time (January) => MST; daylight (July) => MDT.
        let jan = FixedClock(mountain: 2026, month: 1, day: 15, hour: 12).now
        let jul = FixedClock(mountain: 2026, month: 7, day: 15, hour: 12).now
        XCTAssertEqual(MountainTime.abbreviation(at: jan), "MST")
        XCTAssertEqual(MountainTime.abbreviation(at: jul), "MDT")
    }

    func testSpringForwardDayIs23Hours() {
        // 2026-03-08: clocks jump 2:00 -> 3:00. The Mountain day is 23h long.
        let day = CalendarDay(year: 2026, month: 3, day: 8)
        let start = day.startOfDay
        let nextMidnight = MountainTime.nextMidnight(after: start)
        let length = nextMidnight.timeIntervalSince(start)
        XCTAssertEqual(length, 23 * 3600, accuracy: 1)
    }

    func testFallBackDayIs25Hours() {
        // 2026-11-01: clocks fall back 2:00 -> 1:00. The Mountain day is 25h long.
        let day = CalendarDay(year: 2026, month: 11, day: 1)
        let start = day.startOfDay
        let nextMidnight = MountainTime.nextMidnight(after: start)
        let length = nextMidnight.timeIntervalSince(start)
        XCTAssertEqual(length, 25 * 3600, accuracy: 1)
    }

    func testNextMidnightIsLocalMidnightNotUTC() {
        let noon = FixedClock(mountain: 2026, month: 7, day: 20, hour: 12).now
        let midnight = MountainTime.nextMidnight(after: noon)
        let comps = MountainTime.calendar.dateComponents([.hour, .minute, .day], from: midnight)
        XCTAssertEqual(comps.hour, 0)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.day, 21)
    }

    func testStartOfDayGroupsByMountainDay() {
        // 11:30 PM Mountain on the 20th and 12:30 AM on the 21st are different days.
        let late = FixedClock(mountain: 2026, month: 7, day: 20, hour: 23, minute: 30).now
        let early = FixedClock(mountain: 2026, month: 7, day: 21, hour: 0, minute: 30).now
        XCTAssertFalse(MountainTime.isSameDay(late, early))
        XCTAssertEqual(MountainTime.day(for: late), CalendarDay(year: 2026, month: 7, day: 20))
        XCTAssertEqual(MountainTime.day(for: early), CalendarDay(year: 2026, month: 7, day: 21))
    }

    func testResolveNinePMAshwagandhaAcrossDST() {
        // The 9 PM reminder must be 9 PM wall-clock in both MST and MDT.
        let winterDay = CalendarDay(year: 2026, month: 1, day: 15)
        let summerDay = CalendarDay(year: 2026, month: 7, day: 15)
        let winter = MountainTime.date(on: winterDay, at: .ashwagandha)
        let summer = MountainTime.date(on: summerDay, at: .ashwagandha)
        XCTAssertNotNil(winter)
        XCTAssertNotNil(summer)
        XCTAssertEqual(MountainTime.calendar.component(.hour, from: winter!), 21)
        XCTAssertEqual(MountainTime.calendar.component(.hour, from: summer!), 21)
    }

    func testAsiaSessionResolvesToSixPM() {
        let d = CalendarDay(year: 2026, month: 7, day: 20)  // Monday
        let start = MountainTime.date(on: d, at: .asiaSessionStart)
        XCTAssertNotNil(start)
        XCTAssertEqual(MountainTime.calendar.component(.hour, from: start!), 18)
    }
}

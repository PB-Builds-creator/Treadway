import XCTest
@testable import CairnCore

final class HydrationTests: XCTestCase {
    let day = CalendarDay(year: 2026, month: 7, day: 20)
    let ts = FixedClock(mountain: 2026, month: 7, day: 20, hour: 10).now

    func testAddWaterAccumulates() {
        var d = HydrationDay(day: day)
        d = d.adding(8, unit: .fluidOunces, at: ts)
        d = d.adding(16, unit: .fluidOunces, at: ts)
        XCTAssertEqual(d.total(in: .fluidOunces), 24, accuracy: 0.001)
    }

    func testGoalProgressFraction() {
        let goal = HydrationGoal.default   // 200 oz
        var d = HydrationDay(day: day)
        d = d.adding(120, unit: .fluidOunces, at: ts)
        XCTAssertEqual(goal.fraction(for: d), 0.6, accuracy: 0.001)
        XCTAssertEqual(goal.progressLabel(for: d), "120 / 200 oz")
        XCTAssertFalse(goal.isMet(for: d))
    }

    func testProgressFractionClampsAtOne() {
        let goal = HydrationGoal.default
        var d = HydrationDay(day: day)
        d = d.adding(250, unit: .fluidOunces, at: ts)
        XCTAssertEqual(goal.fraction(for: d), 1.0, accuracy: 0.001)
        XCTAssertTrue(goal.isMet(for: d))
    }

    func testNegativeAndZeroAmountsIgnored() {
        var d = HydrationDay(day: day)
        d = d.adding(-50, unit: .fluidOunces, at: ts)
        d = d.adding(0, unit: .fluidOunces, at: ts)
        XCTAssertEqual(d.total(in: .fluidOunces), 0)
    }

    func testCorrectByRemovingEntry() {
        var d = HydrationDay(day: day)
        d = d.adding(8, unit: .fluidOunces, at: ts)
        let mistakenID = d.entries.last!.id
        d = d.adding(16, unit: .fluidOunces, at: ts)
        d = d.removingEntry(mistakenID)
        XCTAssertEqual(d.total(in: .fluidOunces), 16, accuracy: 0.001)
    }

    func testTotalNeverNegativeAfterRemoval() {
        var d = HydrationDay(day: day)
        d = d.adding(8, unit: .fluidOunces, at: ts)
        let id = d.entries.first!.id
        d = d.removingEntry(id)
        XCTAssertEqual(d.total(in: .fluidOunces), 0)
    }

    func testMilliliterStorageIsUnitStable() {
        // Adding in oz and reading in mL should convert correctly (architected for
        // future mL support without data migration).
        var d = HydrationDay(day: day)
        d = d.adding(16, unit: .fluidOunces, at: ts)
        XCTAssertEqual(d.total(in: .milliliters), 16 * 29.5735, accuracy: 0.01)
    }

    func testSetTotalReplacesValue() {
        var d = HydrationDay(day: day)
        d = d.adding(100, unit: .fluidOunces, at: ts)
        d = d.settingTotal(64, unit: .fluidOunces, at: ts)
        XCTAssertEqual(d.total(in: .fluidOunces), 64, accuracy: 0.001)
    }

    func testGoalGuardsAgainstZeroTarget() {
        let goal = HydrationGoal(target: 0)  // clamped to >= 1
        var d = HydrationDay(day: day)
        d = d.adding(10, unit: .fluidOunces, at: ts)
        XCTAssertFalse(goal.fraction(for: d).isNaN)
    }
}

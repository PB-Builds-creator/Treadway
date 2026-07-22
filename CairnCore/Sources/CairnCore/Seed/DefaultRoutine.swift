import Foundation

/// The default routine offered during onboarding. These become ordinary,
/// fully-editable task records once installed — nothing here is hard-coded into
/// the UI. `build(on:)` is deterministic given a reference day.
public enum DefaultRoutine {

    public struct Bundle: Sendable {
        public var categories: [TaskCategory]
        public var tasks: [TaskModel]
        public var hydrationGoal: HydrationGoal
    }

    public static func build(referenceDay: CalendarDay) -> Bundle {
        let faith = TaskCategory(name: "Faith", symbolName: "book.closed", sortIndex: 0)
        let health = TaskCategory(name: "Health", symbolName: "heart", sortIndex: 1)
        let trading = TaskCategory(name: "Trading", symbolName: "chart.line.uptrend.xyaxis", sortIndex: 2)

        func schedule(_ rule: RecurrenceRule) -> RecurrenceEngine.Schedule {
            RecurrenceEngine.Schedule(rule: rule, startDay: referenceDay)
        }

        var index = 0
        func nextIndex() -> Int { defer { index += 1 }; return index }

        let asia = TaskModel(
            title: "Asia Trading Session",
            notes: "6:00–8:00 PM Mountain Time. Prep, execute, journal.",
            categoryID: trading.id,
            symbolName: "chart.line.uptrend.xyaxis",
            priority: .high,
            timing: .window(start: .asiaSessionStart, end: .asiaSessionEnd),
            group: .trading,
            schedule: schedule(.weekdays(Weekday.sundayThroughThursday)),
            reminders: [ReminderRule(kind: .minutesBefore(15))],
            subtasks: AsiaSession.defaultSubtasks.enumerated().map {
                Subtask(title: $0.element, sortIndex: $0.offset)
            },
            sortIndex: nextIndex()
        )

        let food = TaskModel(
            title: "Log all food in MyFitnessPal",
            categoryID: health.id,
            symbolName: "fork.knife",
            timing: .anytime,
            group: .anytime,
            schedule: schedule(.daily),
            reminders: [ReminderRule(kind: .atTime(TimeOfDay(hour: 20, minute: 0)))],
            sortIndex: nextIndex()
        )

        let ashwagandha = TaskModel(
            title: "Take ashwagandha",
            categoryID: health.id,
            symbolName: "pills",
            timing: .at(.ashwagandha),      // 9:00 PM
            group: .beforeBed,
            schedule: schedule(.daily),
            reminders: [ReminderRule(kind: .atTime(.ashwagandha))],
            sortIndex: nextIndex()
        )

        let pray = TaskModel(
            title: "Pray before bed",
            categoryID: faith.id,
            symbolName: "hands.and.sparkles",
            timing: .at(TimeOfDay(hour: 21, minute: 30)),
            group: .beforeBed,
            schedule: schedule(.daily),
            sortIndex: nextIndex()
        )

        let bible = TaskModel(
            title: "Read the Bible app",
            categoryID: faith.id,
            symbolName: "book",
            timing: .at(TimeOfDay(hour: 21, minute: 15)),
            group: .beforeBed,
            schedule: schedule(.daily),
            sortIndex: nextIndex()
        )

        let devotion = TaskModel(
            title: "Complete daily devotion",
            categoryID: faith.id,
            symbolName: "text.book.closed",
            timing: .at(TimeOfDay(hour: 21, minute: 20)),
            group: .beforeBed,
            schedule: schedule(.daily),
            sortIndex: nextIndex()
        )

        let water = TaskModel(
            title: "Drink 200 ounces of water",
            categoryID: health.id,
            symbolName: "drop",
            priority: .normal,
            timing: .anytime,
            group: .anytime,
            schedule: schedule(.daily),
            goal: MeasurableGoal(target: 200, unit: .fluidOunces),
            sortIndex: nextIndex()
        )

        return Bundle(
            categories: [faith, health, trading],
            tasks: [asia, food, ashwagandha, pray, bible, devotion, water],
            hydrationGoal: .default
        )
    }
}

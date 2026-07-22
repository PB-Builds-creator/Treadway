import Foundation
import CairnCore

// A minimal, dependency-free test harness so CairnCore's critical logic can be
// verified without full Xcode (which XCTest/swift-testing require). Mirrors the
// XCTest suite; exits non-zero if any assertion fails.

var failures = 0
var checks = 0

@MainActor
func check(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        print("  ✗ FAIL: \(message)  (\(file):\(line))")
    }
}

func approx(_ a: Double, _ b: Double, _ tol: Double = 0.001) -> Bool { abs(a - b) <= tol }

@MainActor
func section(_ name: String, _ body: () -> Void) {
    print("• \(name)")
    body()
}

func day(_ y: Int, _ m: Int, _ d: Int) -> CalendarDay { CalendarDay(year: y, month: m, day: d) }

let engine = RecurrenceEngine()
func sched(_ rule: RecurrenceRule, _ start: CalendarDay) -> RecurrenceEngine.Schedule {
    RecurrenceEngine.Schedule(rule: rule, startDay: start)
}

section("Recurrence") {
    check(engine.occurs(sched(.daily, day(2026,1,1)), on: day(2026,6,15)), "daily occurs")
    check(!engine.occurs(sched(.daily, day(2026,1,10)), on: day(2026,1,9)), "daily not before start")

    let asia = sched(.weekdays(Weekday.sundayThroughThursday), day(2026,7,1))
    check(engine.occurs(asia, on: day(2026,7,19)), "asia Sun")
    check(engine.occurs(asia, on: day(2026,7,23)), "asia Thu")
    check(!engine.occurs(asia, on: day(2026,7,24)), "asia NOT Fri")
    check(!engine.occurs(asia, on: day(2026,7,25)), "asia NOT Sat")

    check(engine.occurs(sched(.weekly(.wednesday), day(2026,1,1)), on: day(2026,1,7)), "weekly Wed")

    let m = sched(.monthly(day: 31), day(2026,1,1))
    check(engine.occurs(m, on: day(2026,1,31)), "monthly 31 in Jan")
    check(engine.occurs(m, on: day(2026,2,28)), "monthly 31 clamps to Feb 28")
    check(engine.occurs(sched(.monthly(day: 31), day(2028,1,1)), on: day(2028,2,29)), "monthly 31 clamps to leap Feb 29")

    let n = sched(.everyNDays(interval: 3, anchor: day(2026,1,1)), day(2026,1,1))
    check(engine.occurs(n, on: day(2026,1,4)), "everyN +3")
    check(!engine.occurs(n, on: day(2026,1,3)), "everyN not +2")

    var ended = sched(.daily, day(2026,1,1)); ended.endDay = day(2026,1,5)
    check(!engine.occurs(ended, on: day(2026,1,6)), "endDay excludes")

    var paused = sched(.daily, day(2026,1,1)); paused.isPaused = true
    check(!engine.occurs(paused, on: day(2026,1,2)), "pause suppresses")

    var skip = sched(.daily, day(2026,1,1)); skip.skippedDays = [day(2026,1,3)]
    check(!engine.occurs(skip, on: day(2026,1,3)) && engine.occurs(skip, on: day(2026,1,4)), "skip for today")

    check(engine.nextOccurrence(asia, onOrAfter: day(2026,7,24)) == day(2026,7,26), "next occurrence Fri->Sun")
    check(engine.daysBetween(day(2026,12,31), day(2027,1,1)) == 1, "year boundary day math")
}

section("Time zone & DST") {
    check(MountainTime.timeZone.identifier == "America/Denver", "tz is Denver")
    let jan = FixedClock(mountain: 2026, month: 1, day: 15, hour: 12).now
    let jul = FixedClock(mountain: 2026, month: 7, day: 15, hour: 12).now
    check(MountainTime.abbreviation(at: jan) == "MST", "MST in winter")
    check(MountainTime.abbreviation(at: jul) == "MDT", "MDT in summer")

    let springStart = day(2026,3,8).startOfDay
    check(approx(MountainTime.nextMidnight(after: springStart).timeIntervalSince(springStart), 23*3600, 1),
          "spring-forward day is 23h")
    let fallStart = day(2026,11,1).startOfDay
    check(approx(MountainTime.nextMidnight(after: fallStart).timeIntervalSince(fallStart), 25*3600, 1),
          "fall-back day is 25h")

    let winterNine = MountainTime.date(on: day(2026,1,15), at: .ashwagandha)
    let summerNine = MountainTime.date(on: day(2026,7,15), at: .ashwagandha)
    check(MountainTime.calendar.component(.hour, from: winterNine ?? Date()) == 21, "9PM wall-clock winter")
    check(MountainTime.calendar.component(.hour, from: summerNine ?? Date()) == 21, "9PM wall-clock summer")

    let late = FixedClock(mountain: 2026, month: 7, day: 20, hour: 23, minute: 30).now
    let early = FixedClock(mountain: 2026, month: 7, day: 21, hour: 0, minute: 30).now
    check(!MountainTime.isSameDay(late, early), "midnight boundary splits days")
}

section("Hydration") {
    let ts = FixedClock(mountain: 2026, month: 7, day: 20, hour: 10).now
    var d = HydrationDay(day: day(2026,7,20))
    d = d.adding(8, unit: .fluidOunces, at: ts).adding(16, unit: .fluidOunces, at: ts)
    check(approx(d.total(in: .fluidOunces), 24), "accumulate 24oz")

    let goal = HydrationGoal.default
    var g = HydrationDay(day: day(2026,7,20)).adding(120, unit: .fluidOunces, at: ts)
    check(approx(goal.fraction(for: g), 0.6), "fraction 0.6")
    check(goal.progressLabel(for: g) == "120 / 200 oz", "progress label")

    g = g.adding(250, unit: .fluidOunces, at: ts)
    check(approx(goal.fraction(for: g), 1.0), "fraction clamps at 1")

    let neg = HydrationDay(day: day(2026,7,20)).adding(-50, unit: .fluidOunces, at: ts).adding(0, unit: .fluidOunces, at: ts)
    check(neg.total(in: .fluidOunces) == 0, "negative/zero ignored")

    var corr = HydrationDay(day: day(2026,7,20)).adding(8, unit: .fluidOunces, at: ts)
    let mistakeID = corr.entries.last?.id ?? UUID()
    corr = corr.adding(16, unit: .fluidOunces, at: ts).removingEntry(mistakeID)
    check(approx(corr.total(in: .fluidOunces), 16), "correct by removing entry")

    let ml = HydrationDay(day: day(2026,7,20)).adding(16, unit: .fluidOunces, at: ts)
    check(approx(ml.total(in: .milliliters), 16 * 29.5735, 0.01), "mL conversion stable")
    check(!HydrationGoal(target: 0).fraction(for: ml).isNaN, "zero target guarded")
}

section("Streaks") {
    let calc = StreakCalculator()
    let s = RecurrenceEngine.Schedule(rule: .daily, startDay: day(2026,7,1))
    let done: Set<CalendarDay> = [day(2026,7,18), day(2026,7,19), day(2026,7,20)]
    let r = calc.compute(schedule: s, from: day(2026,7,1), through: day(2026,7,20)) { done.contains($0) ? .completed : nil }
    check(r.current == 3, "current streak 3")

    let missed: Set<CalendarDay> = [day(2026,7,18), day(2026,7,20)]
    let r2 = calc.compute(schedule: s, from: day(2026,7,1), through: day(2026,7,20)) { missed.contains($0) ? .completed : nil }
    check(r2.current == 1, "missed day breaks streak")

    // Sun–Thu task not penalized for Fri/Sat.
    let sthu = RecurrenceEngine.Schedule(rule: .weekdays(Weekday.sundayThroughThursday), startDay: day(2026,7,1))
    let sdone: Set<CalendarDay> = [day(2026,7,19),day(2026,7,20),day(2026,7,21),day(2026,7,22),day(2026,7,23),day(2026,7,26)]
    let r3 = calc.compute(schedule: sthu, from: day(2026,7,19), through: day(2026,7,26)) { sdone.contains($0) ? .completed : nil }
    check(r3.current == 6, "weekday streak ignores off-days")
    check(approx(r3.completionRate, 1.0), "completion rate full")
}

section("Today builder") {
    let builder = TodayBuilder()
    func t(_ title: String, _ timing: TaskTiming, _ rule: RecurrenceRule = .daily) -> TaskModel {
        TaskModel(title: title, timing: timing, schedule: sched(rule, day(2026,1,1)))
    }
    let morning = t("Stretch", .at(TimeOfDay(hour: 7, minute: 0)))
    let bed = t("Pray", .at(TimeOfDay(hour: 21, minute: 30)))
    let snap = builder.snapshot(tasks: [bed, morning], on: day(2026,7,20)) { _ in nil }
    check(snap.sections.first?.group == .morning, "morning sorts first")
    check(snap.totalCount == 2 && snap.remainingCount == 2, "counts")

    let a = t("A", .anytime); let b = t("B", .anytime)
    let snap2 = builder.snapshot(tasks: [a, b], on: day(2026,7,20)) { $0 == a.id ? .completed : nil }
    check(snap2.completedCount == 1 && snap2.remainingCount == 1, "completed moves out")

    let snap3 = builder.snapshot(tasks: [a], on: day(2026,7,20)) { _ in .completed }
    check(snap3.isAllDone && snap3.summary == "All done for today.", "all done summary")
}

section("Notifications") {
    let planner = NotificationPlanner()
    let ash = TaskModel(title: "Take ashwagandha", timing: .at(.ashwagandha),
                        schedule: sched(.daily, day(2026,1,1)),
                        reminders: [ReminderRule(kind: .atTime(.ashwagandha))])
    let n = planner.notifications(for: ash, on: day(2026,7,20), status: nil, notificationsEnabledGlobally: true)
    check(n.count == 1 && MountainTime.calendar.component(.hour, from: n.first?.fireDate ?? Date()) == 21, "ashwagandha 9PM")
    check(planner.notifications(for: ash, on: day(2026,7,20), status: .completed, notificationsEnabledGlobally: true).isEmpty, "no notif when completed")
    check(planner.notifications(for: ash, on: day(2026,7,20), status: .skipped, notificationsEnabledGlobally: true).isEmpty, "no notif when skipped")
    check(planner.notifications(for: ash, on: day(2026,7,20), status: nil, notificationsEnabledGlobally: false).isEmpty, "no notif when globally off")

    let water = TaskModel(title: "Water", timing: .anytime, schedule: sched(.daily, day(2026,1,1)),
                          reminders: [ReminderRule(kind: .interval(everyMinutes: 120, start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 0)))],
                          goal: MeasurableGoal(target: 200, unit: .fluidOunces))
    check(planner.notifications(for: water, on: day(2026,7,20), status: nil, notificationsEnabledGlobally: true).count == 7, "7 interval reminders")
}

section("Sync merge") {
    let resolver = MergeResolver()
    let tid = UUID()
    let older = CompletionRecord(taskID: tid, day: day(2026,7,20), status: .completed, updatedAt: Date(timeIntervalSince1970: 100))
    let newer = CompletionRecord(taskID: tid, day: day(2026,7,20), status: .skipped, updatedAt: Date(timeIntervalSince1970: 200))
    let merged = resolver.dedupeCompletions([older, newer])
    check(merged.count == 1 && merged.first?.status == .skipped, "dedupe keeps newest")
    check(resolver.dedupeCompletions([older, newer]) == resolver.dedupeCompletions([newer, older]), "merge order-independent")

    let entry = HydrationDay.Entry(id: UUID(), milliliters: 100, timestamp: Date(timeIntervalSince1970: 1000))
    let h = resolver.mergeHydration([HydrationDay(day: day(2026,7,20), entries: [entry]), HydrationDay(day: day(2026,7,20), entries: [entry])])
    check(h.count == 1 && approx(h.first?.total(in: .milliliters) ?? -1, 100), "hydration union idempotent")
}

section("Seed & archive") {
    let bundle = DefaultRoutine.build(referenceDay: day(2026,7,20))
    check(bundle.tasks.count == 7, "7 default tasks")
    check(bundle.hydrationGoal.target == 200, "200oz goal")
    if let asia = bundle.tasks.first(where: { $0.title == "Asia Trading Session" }),
       case .weekdays(let d) = asia.schedule.rule {
        check(d == Weekday.sundayThroughThursday, "asia Sun-Thu seeded")
        check(asia.subtasks.count == AsiaSession.defaultSubtasks.count, "asia subtasks seeded")
    } else { check(false, "asia session present") }

    do {
        let archive = DataArchive(exportedAt: Date(timeIntervalSince1970: 0),
                                  categories: bundle.categories, tasks: bundle.tasks,
                                  completions: [], hydrationDays: [], hydrationGoal: bundle.hydrationGoal)
        let data = try archive.encoded()
        let restored = try DataArchive.decoded(from: data)
        check(restored.tasks.count == 7 && restored.timeZoneIdentifier == "America/Denver", "archive round-trips")
    } catch {
        check(false, "archive round-trip threw: \(error)")
    }
}

section("Asia session helper") {
    let asia = AsiaSession()
    let fri = FixedClock(mountain: 2026, month: 7, day: 24, hour: 9).now
    let next = asia.nextSession(now: fri)
    check(next.map { MountainTime.day(for: $0.start) } == day(2026,7,26), "Fri -> Sun session")
    check(asia.isLive(now: FixedClock(mountain: 2026, month: 7, day: 20, hour: 19).now), "live at 7PM Mon")
    check(!asia.isLive(now: FixedClock(mountain: 2026, month: 7, day: 20, hour: 17).now), "not live at 5PM Mon")
}

print("\n\(checks) checks, \(failures) failure(s)")
if failures > 0 {
    print("❌ VERIFICATION FAILED")
    exit(1)
} else {
    print("✅ ALL CORE LOGIC VERIFIED")
    exit(0)
}

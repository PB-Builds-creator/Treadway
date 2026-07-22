import SwiftUI
import CairnCore

/// A mutable, UI-friendly representation of a task while editing. Converts to/from
/// the immutable `TaskModel`. Keeps the editor view free of conversion noise.
struct Draft {
    enum TimingKind: Hashable { case anytime, at, window }
    enum RecurrenceKind: Hashable { case daily, weekdays, weekly, monthly, everyN, oneTime }

    var title = ""
    var notes = ""
    var categoryID: UUID?
    var symbolName = "circle"
    var priority: Priority = .normal
    var group: TaskGroup = .anytime

    var timingKind: TimingKind = .anytime
    var startTime = Draft.defaultTime(hour: 9)
    var endTime = Draft.defaultTime(hour: 10)
    var estimatedMinutes = 0

    var recurrenceKind: RecurrenceKind = .daily
    var selectedWeekdays: Set<Weekday> = Weekday.sundayThroughThursday
    var weeklyDay: Weekday = .monday
    var monthlyDay = 1
    var everyN = 2
    var hasEndDate = false
    var endDate = Date()
    var isPaused = false

    var reminders: [ReminderRule] = []
    var subtasks: [Subtask] = []

    var hasGoal = false
    var goalTarget: Double = 200

    init() {}

    init(task: TaskModel) {
        title = task.title
        notes = task.notes
        categoryID = task.categoryID
        symbolName = task.symbolName
        priority = task.priority
        group = task.group
        estimatedMinutes = task.estimatedMinutes ?? 0
        reminders = task.reminders
        subtasks = task.subtasks
        isPaused = task.schedule.isPaused

        switch task.timing {
        case .anytime: timingKind = .anytime
        case .at(let t): timingKind = .at; startTime = Draft.time(from: t)
        case .window(let s, let e): timingKind = .window; startTime = Draft.time(from: s); endTime = Draft.time(from: e)
        }

        switch task.schedule.rule {
        case .daily: recurrenceKind = .daily
        case .weekdays(let days): recurrenceKind = .weekdays; selectedWeekdays = days
        case .weekly(let day): recurrenceKind = .weekly; weeklyDay = day
        case .monthly(let d): recurrenceKind = .monthly; monthlyDay = d
        case .everyNDays(let n, _): recurrenceKind = .everyN; everyN = n
        case .oneTime: recurrenceKind = .oneTime
        }

        if let end = task.schedule.endDay { hasEndDate = true; endDate = end.startOfDay }
        if let goal = task.goal { hasGoal = true; goalTarget = goal.target }
    }

    var currentStartTimeOfDay: TimeOfDay { Draft.timeOfDay(from: startTime) }

    /// Build an immutable model, preserving id/createdAt from `base` when editing.
    func build(from base: TaskModel?) -> TaskModel {
        let timing: TaskTiming
        switch timingKind {
        case .anytime: timing = .anytime
        case .at: timing = .at(Draft.timeOfDay(from: startTime))
        case .window: timing = .window(start: Draft.timeOfDay(from: startTime), end: Draft.timeOfDay(from: endTime))
        }

        let start = base?.schedule.startDay ?? MountainTime.day(for: Date())
        let rule: RecurrenceRule
        switch recurrenceKind {
        case .daily: rule = .daily
        case .weekdays: rule = .weekdays(selectedWeekdays.isEmpty ? [start.weekday] : selectedWeekdays)
        case .weekly: rule = .weekly(weeklyDay)
        case .monthly: rule = .monthly(day: monthlyDay)
        case .everyN: rule = .everyNDays(interval: everyN, anchor: start)
        case .oneTime: rule = .oneTime(start)
        }

        var schedule = RecurrenceEngine.Schedule(
            rule: rule,
            startDay: start,
            endDay: hasEndDate ? MountainTime.day(for: endDate) : nil,
            isPaused: isPaused,
            skippedDays: base?.schedule.skippedDays ?? []
        )
        _ = schedule // silence "never mutated" if not further changed

        return TaskModel(
            id: base?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespaces),
            notes: notes,
            categoryID: categoryID,
            symbolName: symbolName,
            priority: priority,
            timing: timing,
            group: group,
            schedule: schedule,
            reminders: reminders,
            subtasks: subtasks.enumerated().map { Subtask(id: $0.element.id, title: $0.element.title, isDone: $0.element.isDone, sortIndex: $0.offset) },
            goal: hasGoal ? MeasurableGoal(target: goalTarget, unit: .fluidOunces) : nil,
            estimatedMinutes: estimatedMinutes == 0 ? nil : estimatedMinutes,
            isArchived: base?.isArchived ?? false,
            sortIndex: base?.sortIndex ?? Int.max,
            createdAt: base?.createdAt ?? Date()
        )
    }

    // Bridging TimeOfDay <-> Date for SwiftUI's DatePicker.
    static func timeOfDay(from date: Date) -> TimeOfDay {
        let c = MountainTime.calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: c.hour ?? 9, minute: c.minute ?? 0)
    }
    static func time(from tod: TimeOfDay) -> Date { defaultTime(hour: tod.hour, minute: tod.minute) }
    static func defaultTime(hour: Int, minute: Int = 0) -> Date {
        var c = DateComponents(); c.year = 2000; c.month = 1; c.day = 1; c.hour = hour; c.minute = minute
        c.timeZone = MountainTime.timeZone
        return MountainTime.calendar.date(from: c) ?? Date()
    }
}

/// Compact weekday multi-selector.
struct WeekdaySelector: View {
    @Binding var selection: Set<Weekday>
    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(String(day.shortName.prefix(1)))
                        .font(.caption.weight(.medium))
                        .frame(width: 32, height: 32)
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.fullName)
                .accessibilityValue(isOn ? "selected" : "not selected")
            }
        }
    }
}

/// A small curated SF Symbol picker (mature icons, no cartoonish glyphs).
struct SymbolPicker: View {
    @Binding var selection: String
    private let symbols = [
        "circle", "checkmark.circle", "drop", "pills", "fork.knife", "book", "book.closed",
        "text.book.closed", "hands.and.sparkles", "chart.line.uptrend.xyaxis", "figure.run",
        "bed.double", "moon.stars", "sun.max", "heart", "brain.head.profile", "dumbbell",
        "cross.case", "leaf", "cup.and.saucer", "alarm", "flag", "star", "bolt"
    ]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(symbols, id: \.self) { symbol in
                Image(systemName: symbol)
                    .font(.body)
                    .frame(width: 32, height: 32)
                    .background(selection == symbol ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(selection == symbol ? Color.accentColor : .clear))
                    .onTapGesture { selection = symbol }
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selection == symbol ? [.isSelected] : [])
            }
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

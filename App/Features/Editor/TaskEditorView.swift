import SwiftUI
import CairnCore

/// Create/edit a task with all supported fields: title, notes, category, symbol,
/// priority, timing, recurrence, weekdays, dates, reminders, subtasks, measurable
/// goal, duration. Editing a recurring task prompts for scope on save.
struct TaskEditorView: View {
    enum Mode { case create, edit(TaskModel) }

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    private let mode: Mode
    private let original: TaskModel?

    @State private var draft: Draft
    @State private var showScopeDialog = false

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            self.original = nil
            _draft = State(initialValue: Draft())
        case .edit(let task):
            self.original = task
            _draft = State(initialValue: Draft(task: task))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                timingSection
                recurrenceSection
                remindersSection
                subtasksSection
                measurableSection
                if case .edit(let task) = mode { actionsSection(task) }
            }
            .navigationTitle(isCreate ? "New Task" : "Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }.disabled(draft.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("This is a repeating task. Apply your changes to…", isPresented: $showScopeDialog, titleVisibility: .visible) {
                if let original {
                    Button("Only this occurrence") { Task { await env.saveOnlyThis(original: original, edited: draft.build(from: original), on: env.currentDay); dismiss() } }
                    Button("This and future occurrences") { Task { await env.saveThisAndFuture(original: original, edited: draft.build(from: original), from: env.currentDay); dismiss() } }
                    Button("All occurrences") { Task { await env.save(draft.build(from: original)); dismiss() } }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private var isCreate: Bool { if case .create = mode { return true } else { return false } }

    // MARK: - Sections

    private var basicsSection: some View {
        Section("Basics") {
            TextField("Title", text: $draft.title)
            TextField("Notes", text: $draft.notes, axis: .vertical).lineLimit(1...4)
            Picker("TaskCategory", selection: $draft.categoryID) {
                Text("None").tag(UUID?.none)
                ForEach(env.categories) { category in Text(category.name).tag(UUID?.some(category.id)) }
            }
            Picker("Priority", selection: $draft.priority) {
                ForEach(Priority.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            SymbolPicker(selection: $draft.symbolName)
        }
    }

    private var timingSection: some View {
        Section("When") {
            Picker("Time", selection: $draft.timingKind) {
                Text("Anytime").tag(Draft.TimingKind.anytime)
                Text("At a time").tag(Draft.TimingKind.at)
                Text("Time window").tag(Draft.TimingKind.window)
            }
            if draft.timingKind == .at || draft.timingKind == .window {
                DatePicker("Start", selection: $draft.startTime, displayedComponents: .hourAndMinute)
            }
            if draft.timingKind == .window {
                DatePicker("End", selection: $draft.endTime, displayedComponents: .hourAndMinute)
            }
            Picker("Group", selection: $draft.group) {
                ForEach(TaskGroup.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Stepper(value: $draft.estimatedMinutes, in: 0...480, step: 5) {
                Text(draft.estimatedMinutes == 0 ? "No duration" : "~\(draft.estimatedMinutes) min")
            }
        }
    }

    private var recurrenceSection: some View {
        Section("Repeat") {
            Picker("Pattern", selection: $draft.recurrenceKind) {
                Text("Daily").tag(Draft.RecurrenceKind.daily)
                Text("Weekdays").tag(Draft.RecurrenceKind.weekdays)
                Text("Weekly").tag(Draft.RecurrenceKind.weekly)
                Text("Monthly").tag(Draft.RecurrenceKind.monthly)
                Text("Every N days").tag(Draft.RecurrenceKind.everyN)
                Text("One time").tag(Draft.RecurrenceKind.oneTime)
            }
            if draft.recurrenceKind == .weekdays {
                WeekdaySelector(selection: $draft.selectedWeekdays)
            }
            if draft.recurrenceKind == .weekly {
                Picker("On", selection: $draft.weeklyDay) {
                    ForEach(Weekday.allCases, id: \.self) { Text($0.fullName).tag($0) }
                }
            }
            if draft.recurrenceKind == .monthly {
                Stepper("Day \(draft.monthlyDay)", value: $draft.monthlyDay, in: 1...31)
            }
            if draft.recurrenceKind == .everyN {
                Stepper("Every \(draft.everyN) days", value: $draft.everyN, in: 1...60)
            }
            Toggle("Set end date", isOn: $draft.hasEndDate)
            if draft.hasEndDate {
                DatePicker("Ends", selection: $draft.endDate, displayedComponents: .date)
            }
            Toggle("Pause repeating", isOn: $draft.isPaused)
        }
    }

    private var remindersSection: some View {
        Section("Reminders") {
            ForEach($draft.reminders) { $reminder in
                Toggle(isOn: $reminder.isEnabled) { Text(reminderLabel(reminder)) }
            }
            .onDelete { draft.reminders.remove(atOffsets: $0) }
            Button {
                draft.reminders.append(ReminderRule(kind: .atTime(draft.currentStartTimeOfDay)))
            } label: { Label("Add reminder at start time", systemImage: "bell.badge.plus") }
            Button {
                draft.reminders.append(ReminderRule(kind: .minutesBefore(15)))
            } label: { Label("Add reminder 15 min before", systemImage: "bell.badge.plus") }
        }
    }

    private var subtasksSection: some View {
        Section("Subtasks") {
            ForEach($draft.subtasks) { $subtask in
                TextField("Step", text: $subtask.title)
            }
            .onDelete { draft.subtasks.remove(atOffsets: $0) }
            Button {
                draft.subtasks.append(Subtask(title: "", sortIndex: draft.subtasks.count))
            } label: { Label("Add subtask", systemImage: "plus") }
        }
    }

    private var measurableSection: some View {
        Section("Measurable goal") {
            Toggle("Track a numeric goal", isOn: $draft.hasGoal)
            if draft.hasGoal {
                HStack {
                    Text("Target")
                    Spacer()
                    TextField("Amount", value: $draft.goalTarget, format: .number)
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .frame(width: 80)
                    Text("oz").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func actionsSection(_ task: TaskModel) -> some View {
        Section {
            Button { Task { await env.duplicate(task); dismiss() } } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button { Task { await env.setArchived(!task.isArchived, taskID: task.id); dismiss() } } label: {
                Label(task.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }
            Button(role: .destructive) { Task { await env.delete(taskID: task.id); dismiss() } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Save

    private func attemptSave() {
        let built = draft.build(from: original)
        if let original, isRecurring(original.schedule.rule) {
            showScopeDialog = true
        } else {
            Task { await env.save(built); dismiss() }
        }
    }

    private func isRecurring(_ rule: RecurrenceRule) -> Bool {
        if case .oneTime = rule { return false }
        return true
    }

    private func reminderLabel(_ reminder: ReminderRule) -> String {
        switch reminder.kind {
        case .atTime(let time): return "At \(time.displayString)"
        case .minutesBefore(let m): return "\(m) min before"
        case .interval(let every, let start, let end): return "Every \(every) min, \(start.displayString)–\(end.displayString)"
        }
    }
}

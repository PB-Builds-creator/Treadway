import SwiftUI
import CairnCore

/// Private insights: completion rate, current/longest streaks per task, hydration
/// history, and a month completion grid. Calm and non-gamified — no badges, no shame.
struct HistoryView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings

    @State private var rows: [TaskInsight] = []
    @State private var monthCells: [DayCell] = []
    @State private var overallRate: Double = 0
    @State private var isLoading = false

    struct TaskInsight: Identifiable {
        let task: TaskModel
        let current: Int
        let longest: Int
        let rate: Double
        var id: UUID { task.id }
    }
    struct DayCell: Identifiable {
        let day: CalendarDay
        let fraction: Double
        var id: CalendarDay { day }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                if isLoading && rows.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(DS.Spacing.xxl)
                } else if rows.isEmpty {
                    EmptyStateView(symbol: "chart.bar", title: "No history yet",
                                   message: "Complete a few tasks and your consistency will show up here.")
                        .frame(maxWidth: .infinity)
                } else {
                    overallSection
                    monthGridSection
                    streaksSection
                }
            }
            .padding(.vertical, DS.Spacing.l)
        }
        .navigationTitle("History")
        .task { await load() }
    }

    private var overallSection: some View {
        HStack(spacing: DS.Spacing.l) {
            ProgressRing(fraction: overallRate, lineWidth: 8,
                         label: "\(Int(overallRate * 100))%", caption: "30-day")
                .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Consistency").font(.headline)
                Text("Your completion rate over the last 30 days.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.l)
    }

    private var monthGridSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            GroupHeader(title: "Last 30 days")
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 10)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(monthCells) { cell in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.15 + 0.85 * cell.fraction))
                        .frame(height: 22)
                        .overlay(Text("\(cell.day.day)").font(.system(size: 8)).foregroundStyle(.secondary))
                        .accessibilityLabel("\(cell.day.month)/\(cell.day.day): \(Int(cell.fraction * 100)) percent complete")
                }
            }
            .padding(.horizontal, DS.Spacing.l)
        }
    }

    private var streaksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: "Streaks")
            ForEach(rows) { row in
                HStack(spacing: DS.Spacing.m) {
                    Image(systemName: row.task.symbolName).foregroundStyle(.tertiary).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.task.title).font(.cairnRow)
                        Text("\(Int(row.rate * 100))% completion").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(row.current)").font(.headline).monospacedDigit()
                        Text("best \(row.longest)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DS.Spacing.l)
                .padding(.vertical, DS.Spacing.s)
                .accessibilityElement(children: .combine)
                if row.id != rows.last?.id { HairlineDivider().padding(.leading, 50) }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let engine = RecurrenceEngine()
        let calc = StreakCalculator(engine: engine)
        let today = env.currentDay
        let from = startDay(daysBack: 29, from: today, engine: engine)

        let tasks = (try? await env.store.allTasks()) ?? []
        let completions = (try? await env.store.completions(from: from, through: today)) ?? []
        var statusByTaskDay: [String: CompletionStatus] = [:]
        for record in completions { statusByTaskDay[record.naturalKey] = record.status }

        func status(_ taskID: UUID, _ day: CalendarDay) -> CompletionStatus? {
            statusByTaskDay["\(taskID.uuidString)#\(day.year)-\(day.month)-\(day.day)"]
        }

        // Per-task streaks.
        rows = tasks.map { task in
            let result = calc.compute(schedule: task.schedule, from: from, through: today, referenceDay: today) {
                status(task.id, $0)
            }
            return TaskInsight(task: task, current: result.current, longest: result.longest, rate: result.completionRate)
        }
        .sorted { $0.current > $1.current }

        // Month grid + overall rate.
        var cells: [DayCell] = []
        var scheduledTotal = 0, completedTotal = 0
        var cursor = from
        while cursor <= today {
            let due = tasks.filter { !$0.isArchived && engine.occurs($0.schedule, on: cursor) }
            let done = due.filter { status($0.id, cursor) == .completed || status($0.id, cursor) == .partial }.count
            scheduledTotal += due.count
            completedTotal += done
            cells.append(DayCell(day: cursor, fraction: due.isEmpty ? 0 : Double(done) / Double(due.count)))
            cursor = engine.addingOneDay(to: cursor)
        }
        monthCells = cells
        overallRate = scheduledTotal == 0 ? 0 : Double(completedTotal) / Double(scheduledTotal)
    }

    private func startDay(daysBack: Int, from day: CalendarDay, engine: RecurrenceEngine) -> CalendarDay {
        var d = day
        for _ in 0..<daysBack {
            d = MountainTime.day(for: MountainTime.calendar.date(byAdding: .day, value: -1, to: d.startOfDay) ?? d.startOfDay)
        }
        return d
    }
}

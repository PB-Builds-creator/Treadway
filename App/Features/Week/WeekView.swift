import SwiftUI
import CairnCore

/// A calm week overview: one row per day with completion %, scheduled/missed/done
/// counts, hydration, and the trading-session marker. Navigable across weeks.
struct WeekView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings

    @State private var weekOffset = 0
    @State private var days: [DaySummary] = []
    @State private var isLoading = false

    struct DaySummary: Identifiable {
        let day: CalendarDay
        let isToday: Bool
        let scheduled: Int
        let completed: Int
        let missed: Int
        let hydrationFraction: Double
        let hasTradingSession: Bool
        var id: CalendarDay { day }
        var fraction: Double { scheduled == 0 ? 0 : Double(completed) / Double(scheduled) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                weekNavigator
                if isLoading && days.isEmpty {
                    ProgressView().padding(DS.Spacing.xxl)
                } else {
                    ForEach(days) { summary in
                        dayRow(summary)
                        if summary.id != days.last?.id { HairlineDivider().padding(.leading, DS.Spacing.l) }
                    }
                }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
        .navigationTitle("Week")
        .task(id: weekOffset) { await load() }
    }

    private var weekNavigator: some View {
        HStack {
            Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityLabel("Previous week")
            Spacer()
            Text(weekRangeLabel).font(.headline)
            Spacer()
            Button { weekOffset += 1 } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityLabel("Next week")
                .disabled(weekOffset >= 0)
        }
        .buttonStyle(.bordered)
        .padding(DS.Spacing.l)
    }

    private func dayRow(_ s: DaySummary) -> some View {
        HStack(spacing: DS.Spacing.l) {
            VStack(spacing: 2) {
                Text(s.day.weekday.shortName).font(.caption).foregroundStyle(.secondary)
                Text("\(s.day.day)").font(.title3.weight(s.isToday ? .bold : .regular))
                    .foregroundStyle(s.isToday ? Color.accentColor : .primary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.s) {
                    Text("\(s.completed)/\(s.scheduled) done").font(.subheadline)
                    if s.missed > 0 {
                        Text("· \(s.missed) missed").font(.caption).foregroundStyle(.secondary)
                    }
                    if s.hasTradingSession {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2).foregroundStyle(.secondary)
                            .accessibilityLabel("Asia trading session")
                    }
                }
                ThinProgressBar(fraction: s.fraction)
                if s.hydrationFraction > 0 {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "drop").font(.caption2).foregroundStyle(.secondary)
                        ThinProgressBar(fraction: s.hydrationFraction, height: 4)
                    }
                }
            }
            Spacer()
            Text("\(Int(s.fraction * 100))%").font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let engine = RecurrenceEngine()
        let asia = AsiaSession()
        let cal = MountainTime.calendar
        let today = env.currentDay

        // Compute the start of the displayed week honoring weekStartsOn.
        guard let base = cal.date(byAdding: .weekOfYear, value: weekOffset, to: env.clock.now) else { return }
        let weekdayIndex = cal.component(.weekday, from: base)
        let desiredStart = settings.weekStartsOn.rawValue
        let deltaToStart = ((weekdayIndex - desiredStart) % 7 + 7) % 7
        guard let startDate = cal.date(byAdding: .day, value: -deltaToStart, to: cal.startOfDay(for: base)) else { return }

        let tasks = (try? await env.store.allTasks()) ?? []
        var result: [DaySummary] = []
        for offset in 0..<7 {
            guard let date = cal.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let day = MountainTime.day(for: date)
            let statusMap = (try? await env.store.statusMap(on: day)) ?? [:]
            let due = tasks.filter { !$0.isArchived && engine.occurs($0.schedule, on: day) }
            let completed = due.filter { statusMap[$0.id] == .completed || statusMap[$0.id] == .partial }.count
            // "Missed" only applies to past days.
            let missed = day < today ? due.count - completed - due.filter { statusMap[$0.id] == .skipped }.count : 0
            let hyd = (try? await env.store.hydrationDay(day)) ?? HydrationDay(day: day)
            result.append(DaySummary(
                day: day,
                isToday: day == today,
                scheduled: due.count,
                completed: completed,
                missed: max(0, missed),
                hydrationFraction: settings.hydrationGoal.fraction(for: hyd),
                hasTradingSession: due.contains { $0.group == .trading } || asia.nextSession(now: date).map { MountainTime.isSameDay($0.start, date) } ?? false
            ))
        }
        days = result
    }

    private var weekRangeLabel: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "This Week" }
        let f = DateFormatter(); f.timeZone = MountainTime.timeZone; f.dateFormat = "MMM d"
        return "\(f.string(from: first.startOfDay)) – \(f.string(from: last.startOfDay))"
    }
}

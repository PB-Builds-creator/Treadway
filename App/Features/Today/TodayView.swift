import SwiftUI
import CairnCore

/// The default dashboard: date, Mountain-Time indicator, completion summary,
/// hydration, and tasks grouped by time of day. Only non-empty groups render.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings

    @State private var editingTask: TaskModel?
    @State private var showingNewTask = false
    @State private var showingCompleted = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                header
                if let snapshot = env.todaySnapshot {
                    summaryCard(snapshot)
                    hydrationSection
                    ForEach(snapshot.sections) { section in
                        groupSection(section)
                    }
                    if snapshot.totalCount == 0 {
                        EmptyStateView(
                            symbol: "checklist",
                            title: "Nothing scheduled today",
                            message: "Add a task, or install your default routine from Settings."
                        )
                        .frame(maxWidth: .infinity)
                    }
                    completedDisclosure(snapshot)
                } else {
                    ProgressView().padding(DS.Spacing.xxl).frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
        .navigationTitle("Today")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingNewTask = true } label: { Label("Add Task", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
        .refreshable { await env.refresh() }
        .sheet(isPresented: $showingNewTask) {
            TaskEditorView(mode: .create)
        }
        .sheet(item: $editingTask) { task in
            TaskEditorView(mode: .edit(task))
        }
        .task { await env.refresh() }
        .overlay(alignment: .bottom) { errorBanner }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .cairnNewTask)) { _ in
            showingNewTask = true
        }
        #endif
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(dateString).font(.cairnTitle)
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "mountain.2").font(.caption2)
                Text("\(MountainTime.displayName) · \(MountainTime.abbreviation(at: env.clock.now))")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.l)
        .padding(.top, DS.Spacing.s)
    }

    private func summaryCard(_ s: TodayBuilder.Snapshot) -> some View {
        HStack(spacing: DS.Spacing.l) {
            ProgressRing(
                fraction: s.completionFraction,
                lineWidth: 8,
                label: "\(Int(s.completionFraction * 100))%",
                caption: "Done"
            )
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(s.summary).font(.headline)
                Text("\(s.completedCount) completed · \(s.remainingCount) remaining")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(DS.Spacing.l)
        .padding(.top, DS.Spacing.s)
    }

    @ViewBuilder private var hydrationSection: some View {
        if let hydration = env.hydrationDay {
            GroupHeader(title: "Hydration")
            HydrationCard(day: hydration, goal: settings.hydrationGoal)
                .padding(.horizontal, DS.Spacing.l)
        }
    }

    private func groupSection(_ section: TodayBuilder.Section) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupHeader(title: section.group.title, trailing: "\(section.items.count)")
            ForEach(section.items) { item in
                VStack(spacing: 0) {
                    TaskRow(
                        item: item,
                        onToggle: { Task { await env.toggleComplete(item) } },
                        onOpenDeepLink: deepLinkAction(for: item.task)
                    )
                    .onTapGesture { editingTask = item.task }
                    // Skip / Archive live in the context menu (long-press on iOS,
                    // right-click on macOS). swipeActions is intentionally NOT used
                    // here because it is a no-op outside a `List`.
                    .contextMenu {
                        Button("Edit") { editingTask = item.task }
                        Button("Skip today") { Task { await env.skipToday(taskID: item.task.id) } }
                        Button("Archive") { Task { await env.setArchived(true, taskID: item.task.id) } }
                    }
                    if item.id != section.items.last?.id { HairlineDivider().padding(.leading, 60) }
                }
            }
        }
    }

    @ViewBuilder private func completedDisclosure(_ s: TodayBuilder.Snapshot) -> some View {
        if s.completedCount > 0 {
            DisclosureGroup(isExpanded: $showingCompleted) {
                ForEach(s.completedSections) { section in
                    ForEach(section.items) { item in
                        TaskRow(item: item, onToggle: { Task { await env.toggleComplete(item) } })
                    }
                }
            } label: {
                Text("Completed (\(s.completedCount))").font(.cairnSection).foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.top, DS.Spacing.l)
        }
    }

    @ViewBuilder private var errorBanner: some View {
        if let error = env.loadError {
            Text(error)
                .font(.footnote)
                .padding(DS.Spacing.m)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .padding(DS.Spacing.l)
        }
    }

    // MARK: - Helpers

    private func deepLinkAction(for task: TaskModel) -> (() -> Void)? {
        let lower = task.title.lowercased()
        if lower.contains("myfitnesspal") {
            return { env.deepLinker.openMyFitnessPal(scheme: settings.myFitnessPalURL) }
        }
        if lower.contains("bible") {
            return { env.deepLinker.openBible(scheme: settings.bibleAppURL) }
        }
        return nil
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.calendar = MountainTime.calendar
        formatter.timeZone = MountainTime.timeZone
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: env.clock.now)
    }
}

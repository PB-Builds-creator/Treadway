import SwiftUI
import CairnCore

/// A single task row. One tap on the checkbox completes it. Status is shown by BOTH
/// the checkmark shape and text — never color alone.
struct TaskRow: View {
    let item: TodayBuilder.Item
    var onToggle: () -> Void
    var onOpenDeepLink: (() -> Void)?

    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(item.isDone ? Color.accentColor : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: DS.Symbol.hitTarget, height: DS.Symbol.hitTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.task.title) not done" : "Complete \(item.task.title)")
            .accessibilityAddTraits(item.isDone ? [.isSelected] : [])

            VStack(alignment: .leading, spacing: 2) {
                Text(item.task.title)
                    .font(.cairnRow)
                    .strikethrough(item.isDone, color: .secondary)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: DS.Spacing.s)

            if item.task.priority == .high && !item.isDone {
                Image(systemName: "exclamationmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("High priority")
            }
            if let onOpenDeepLink {
                Button(action: onOpenDeepLink) {
                    Image(systemName: "arrow.up.forward.app").font(.body)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .frame(width: DS.Symbol.hitTarget, height: DS.Symbol.hitTarget)
                .accessibilityLabel("Open linked app")
            }
            Image(systemName: item.task.symbolName)
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(width: 24)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.xs)
        .contentShape(Rectangle())
    }

    private var subtitle: String? {
        var parts: [String] = []
        if let anchor = item.task.timing.anchorTime { parts.append(anchor.displayString) }
        if !item.task.subtasks.isEmpty {
            let done = item.task.subtasks.filter(\.isDone).count
            parts.append("\(done)/\(item.task.subtasks.count) steps")
        }
        if let mins = item.task.estimatedMinutes { parts.append("~\(mins) min") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

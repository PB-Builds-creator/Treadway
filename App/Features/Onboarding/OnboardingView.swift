import SwiftUI
import CairnCore

/// First-launch onboarding. Offers to install the default routine (which then
/// becomes ordinary, editable task records — nothing is hard-coded into the UI).
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            Image(systemName: "mountain.2")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(Color.accentColor)
            VStack(spacing: DS.Spacing.s) {
                Text("Cairn").font(.system(.largeTitle, weight: .semibold))
                Text("A quiet daily dashboard for your routine, on \(MountainTime.displayName).")
                    .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.m) {
                bullet("checklist", "Only today's tasks, grouped by time of day")
                bullet("drop", "Hydration tracking toward your daily goal")
                bullet("chart.line.uptrend.xyaxis", "Your Asia session, Sunday–Thursday")
                bullet("lock.shield", "Private: on-device and your own iCloud")
            }
            .frame(maxWidth: 360)

            Spacer()

            VStack(spacing: DS.Spacing.s) {
                Button {
                    Task {
                        await env.installDefaultRoutineIfNeeded()
                        settings.hasCompletedOnboarding = true
                        dismiss()
                    }
                } label: {
                    Text("Install my default routine").frame(maxWidth: .infinity, minHeight: DS.Symbol.hitTarget)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    settings.hasCompletedOnboarding = true
                    dismiss()
                } label: {
                    Text("Start empty").frame(maxWidth: .infinity, minHeight: DS.Symbol.hitTarget)
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: 360)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 620)
        #endif
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 26)
            Text(text).font(.subheadline)
            Spacer()
        }
    }
}

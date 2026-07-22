import SwiftUI
import CairnCore

/// Compact hydration card for the Today screen: progress bar, total, quick-add.
struct HydrationCard: View {
    @Environment(AppEnvironment.self) private var env
    let day: HydrationDay
    let goal: HydrationGoal
    @State private var showingDetail = false

    private let quickAdds: [Double] = [8, 16, 20, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack {
                Label(goal.progressLabel(for: day), systemImage: "drop.fill")
                    .font(.subheadline.weight(.medium))
                    .labelStyle(.titleAndIcon)
                Spacer()
                Text("\(Int(goal.fraction(for: day) * 100))%")
                    .font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
            }
            ThinProgressBar(fraction: goal.fraction(for: day))

            HStack(spacing: DS.Spacing.s) {
                ForEach(quickAdds, id: \.self) { amount in
                    Button {
                        Task { await env.addWater(amount) }
                        Haptics.tap()
                    } label: {
                        Text("+\(Int(amount))")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add \(Int(amount)) ounces")
                }
                Button { showingDetail = true } label: {
                    Image(systemName: "ellipsis").frame(minHeight: 34).padding(.horizontal, DS.Spacing.s)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Hydration details")
            }
        }
        .padding(DS.Spacing.l)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .sheet(isPresented: $showingDetail) {
            HydrationDetailView(goal: goal)
        }
    }
}

/// Full hydration editor: custom amount, edit goal, per-entry correction.
struct HydrationDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    let goal: HydrationGoal

    @State private var customAmount = ""

    var body: some View {
        NavigationStack {
            Form {
                if let day = env.hydrationDay {
                    Section {
                        HStack {
                            ProgressRing(fraction: goal.fraction(for: day), lineWidth: 10,
                                         label: "\(Int(day.total(in: .fluidOunces)))",
                                         caption: "oz")
                                .frame(width: 90, height: 90)
                            VStack(alignment: .leading) {
                                Text(goal.progressLabel(for: day)).font(.headline)
                                Text(goal.isMet(for: day) ? "Goal reached" : "\(Int(max(0, goal.target - day.total(in: .fluidOunces)))) oz to go")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    Section("Add a custom amount") {
                        HStack {
                            TextField("Ounces", text: $customAmount)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                            Button("Add") {
                                if let value = Double(customAmount), value > 0 {
                                    Task { await env.addWater(value) }
                                    customAmount = ""
                                }
                            }
                            .disabled(Double(customAmount) == nil)
                        }
                    }

                    Section("Daily goal") {
                        Stepper(value: Binding(
                            get: { settings.hydrationTargetOunces },
                            set: { settings.hydrationTargetOunces = max(1, $0) }
                        ), in: 8...400, step: 8) {
                            Text("\(Int(settings.hydrationTargetOunces)) oz")
                        }
                    }

                    Section("Today's entries") {
                        if day.entries.isEmpty {
                            Text("No water logged yet.").foregroundStyle(.secondary)
                        }
                        ForEach(day.entries) { entry in
                            HStack {
                                Text("\(Int(entry.milliliters / MeasurementUnit.fluidOunces.toMilliliters)) oz")
                                Spacer()
                                Text(entry.timestamp, style: .time).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let id = day.entries[index].id
                                Task { await env.removeHydrationEntry(id) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hydration")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

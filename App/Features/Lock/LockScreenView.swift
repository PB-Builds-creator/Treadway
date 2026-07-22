import SwiftUI

/// Shown over blurred content when the app is locked.
struct LockScreenView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Cairn is locked").font(.title3.weight(.semibold))
            Button {
                Task { await env.lock.authenticate() }
            } label: {
                Label("Unlock with \(env.lock.biometryTypeDescription)", systemImage: "faceid")
                    .frame(minWidth: 220, minHeight: DS.Symbol.hitTarget)
            }
            .buttonStyle(.borderedProminent)
            if let error = env.lock.lastError {
                Text(error).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .accessibilityAddTraits(.isModal)
    }
}

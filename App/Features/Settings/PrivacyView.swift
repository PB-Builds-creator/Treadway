import SwiftUI

/// Plain-language privacy explanation. No tracking, no third parties.
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                privacyItem("What's stored",
                            "Your tasks, completion history, hydration entries, categories, and preferences.")
                privacyItem("Where it's stored",
                            "On this device using Apple's on-device database, and synced through your own private iCloud account (CloudKit private database). It is never sent to any server operated by this app.")
                privacyItem("No selling, no analytics",
                            "Your data is never sold or shared. There are no third-party analytics or advertising SDKs, and no tracking of any kind.")
                privacyItem("No account",
                            "There's no sign-up and no password to this app. Access is protected by your device and optional Face ID / Touch ID.")
                privacyItem("Export your data",
                            "Settings → Data → Export produces a readable JSON file you fully control.")
                privacyItem("Delete your data",
                            "Settings → Data → Delete all data removes everything from this device. Because sync uses your iCloud, also delete the app's iCloud data from Settings → [your name] → iCloud → Manage Account Storage if you want to remove synced copies.")
            }
            .padding(DS.Spacing.l)
        }
        .navigationTitle("Privacy")
    }

    private func privacyItem(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

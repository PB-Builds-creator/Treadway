import SwiftUI
import UniformTypeIdentifiers
import CairnCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings

    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: ArchiveDocument?
    @State private var confirmReset = false
    @State private var confirmDeleteAll = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                Picker("Accent", selection: $settings.accentColorName) {
                    ForEach(AccentColorName.allCases) { name in
                        Label { Text(name.label) } icon: { Circle().fill(name.color).frame(width: 14, height: 14) }.tag(name)
                    }
                }
                Picker("Week starts on", selection: $settings.weekStartsOn) {
                    ForEach([Weekday.sunday, .monday], id: \.self) { Text($0.fullName).tag($0) }
                }
            }

            Section("Hydration") {
                Stepper("Daily goal: \(Int(settings.hydrationTargetOunces)) oz",
                        value: $settings.hydrationTargetOunces, in: 8...400, step: 8)
            }

            Section("Notifications") {
                Toggle("Enable notifications", isOn: $settings.notificationsEnabled)
                Toggle("Daily summary", isOn: $settings.dailySummaryEnabled)
                if settings.dailySummaryEnabled {
                    timePicker("Summary time", $settings.dailySummaryTime)
                }
                Toggle("Before-bed summary", isOn: $settings.beforeBedSummaryEnabled)
                if settings.beforeBedSummaryEnabled {
                    timePicker("Before-bed time", $settings.beforeBedSummaryTime)
                }
                Text("Times use \(MountainTime.displayName).").font(.caption).foregroundStyle(.secondary)
            }

            Section("Security") {
                Toggle("Require \(env.lock.biometryTypeDescription)", isOn: $settings.appLockEnabled)
                if settings.appLockEnabled {
                    Toggle("Lock when backgrounded", isOn: $settings.lockOnBackground)
                    Picker("Auto-lock after", selection: $settings.autoLockGraceSeconds) {
                        Text("Immediately").tag(0)
                        Text("1 minute").tag(60)
                        Text("5 minutes").tag(300)
                        Text("15 minutes").tag(900)
                    }
                }
            }

            Section("Integrations") {
                LabeledContent("MyFitnessPal link") {
                    TextField("URL scheme", text: $settings.myFitnessPalURL).multilineTextAlignment(.trailing)
                }
                LabeledContent("Bible app link") {
                    TextField("URL scheme", text: $settings.bibleAppURL).multilineTextAlignment(.trailing)
                }
                Text("Used by the open-app button on those tasks. Falls back to the website if the app isn't installed.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Categories") {
                NavigationLink { CategoryManagerView() } label: { Label("Manage categories", systemImage: "folder") }
            }

            Section("Data") {
                Button { Task { await prepareExport() } } label: { Label("Export data (JSON)", systemImage: "square.and.arrow.up") }
                Button { showingImporter = true } label: { Label("Import data", systemImage: "square.and.arrow.down") }
                Button { confirmReset = true } label: { Label("Reset to default routine", systemImage: "arrow.counterclockwise") }
                Button(role: .destructive) { confirmDeleteAll = true } label: { Label("Delete all data", systemImage: "trash") }
            }

            Section("About") {
                NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "lock.shield") }
                LabeledContent("Time zone", value: "\(MountainTime.displayName) (America/Denver)")
                LabeledContent("Version", value: "1.0")
            }
        }
        .navigationTitle("Settings")
        .formStyle(.grouped)
        .fileExporter(isPresented: $showingExporter, document: exportDocument,
                      contentType: .json, defaultFilename: "Cairn-Backup") { _ in }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            Task { await handleImport(result) }
        }
        .confirmationDialog("Reset to the default routine? Your current tasks and history will be deleted.",
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { Task { await env.resetToTemplate() } }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete all data? This cannot be undone.",
                            isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { Task { await env.deleteAllData() } }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func timePicker(_ title: String, _ binding: Binding<TimeOfDay>) -> some View {
        DatePicker(title, selection: Binding(
            get: { Draft.time(from: binding.wrappedValue) },
            set: { binding.wrappedValue = Draft.timeOfDay(from: $0) }
        ), displayedComponents: .hourAndMinute)
    }

    private func prepareExport() async {
        if let archive = await env.exportArchive(), let data = try? archive.encoded() {
            exportDocument = ArchiveDocument(data: data)
            showingExporter = true
        }
    }

    private func handleImport(_ result: Result<URL, Error>) async {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url), let archive = try? DataArchive.decoded(from: data) {
            await env.importArchive(archive)
        }
    }
}

/// FileDocument wrapper for JSON export/import.
struct ArchiveDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

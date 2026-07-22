import SwiftUI
import SwiftData
import CairnCore

@main
struct CairnApp: App {
    @State private var env: AppEnvironment
    @State private var settings: AppSettings
    private let container: ModelContainer
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let container = PersistenceController.makeContainer()
        let settings = AppSettings()
        let store = Store(modelContainer: container)
        self.container = container
        _settings = State(initialValue: settings)
        _env = State(initialValue: AppEnvironment(store: store, settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(settings)
                .modelContainer(container)
                .tint(settings.accentColorName.color)
                .preferredColorScheme(settings.appearance.colorScheme)
                .task {
                    await env.installDefaultRoutineIfNeeded()
                    await env.lock.lockIfEnabledAtLaunch()
                }
                .onChange(of: scenePhase) { _, phase in
                    env.lock.handleScenePhase(phase)
                    if phase == .active { Task { await env.refresh() } }
                }
        }
        #if os(macOS)
        .commands { CairnCommands(env: env) }
        .defaultSize(width: 980, height: 720)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .environment(env)
                .environment(settings)
                .frame(width: 480, height: 560)
        }
        #endif
    }
}

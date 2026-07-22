import SwiftUI
import CairnCore

/// Top-level navigation. iPhone uses a tab bar; Mac and iPad use a sidebar
/// (`NavigationSplitView`) so the desktop layout is genuinely adapted, not a
/// stretched phone UI. Also hosts onboarding, the app-lock gate, and the privacy
/// cover in the app-switcher.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(AppSettings.self) private var settings
    @State private var selection: Tab = .today

    enum Tab: String, CaseIterable, Identifiable {
        case today, week, history, settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .today: return "Today"
            case .week: return "Week"
            case .history: return "History"
            case .settings: return "Settings"
            }
        }
        var symbol: String {
            switch self {
            case .today: return "sun.max"
            case .week: return "calendar"
            case .history: return "chart.bar"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        ZStack {
            content
                .disabled(env.lock.isLocked)
                .blur(radius: env.lock.isLocked ? 20 : 0)

            if env.lock.isLocked {
                LockScreenView().transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: env.lock.isLocked)
        .privacyCover(active: env.lock.shouldShowPrivacyCover)
        .sheet(isPresented: Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
                .interactiveDismissDisabled(true)
        }
    }

    @ViewBuilder private var content: some View {
        #if os(iOS)
        if horizontalIsCompact {
            TabView(selection: $selection) {
                ForEach(Tab.allCases) { tab in
                    NavigationStack { screen(for: tab) }
                        .tabItem { Label(tab.title, systemImage: tab.symbol) }
                        .tag(tab)
                }
            }
        } else {
            splitView
        }
        #else
        splitView
        #endif
    }

    private var splitView: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                NavigationLink(value: tab) {
                    Label(tab.title, systemImage: tab.symbol)
                }
            }
            .navigationTitle("Cairn")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
        } detail: {
            NavigationStack { screen(for: selection) }
        }
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSize
    private var horizontalIsCompact: Bool { hSize == .compact }
    #endif

    @ViewBuilder private func screen(for tab: Tab) -> some View {
        switch tab {
        case .today: TodayView()
        case .week: WeekView()
        case .history: HistoryView()
        case .settings: SettingsView()
        }
    }
}

// MARK: - Privacy cover (hides content in the app switcher)

private struct PrivacyCoverModifier: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        content.overlay {
            if active {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Image(systemName: "mountain.2")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func privacyCover(active: Bool) -> some View { modifier(PrivacyCoverModifier(active: active)) }
}

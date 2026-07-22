import Foundation
import SwiftUI
import CairnCore

/// User preferences, backed by UserDefaults in the shared app group so widgets and
/// intents read the same values. No sensitive task data is stored here.
@MainActor
@Observable
final class AppSettings {
    static let suiteName = "group.com.paxton.cairn"
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.suiteName) ?? .standard
        load()
    }

    // Appearance
    var appearance: AppearanceMode = .system { didSet { save() } }
    var accentColorName: AccentColorName = .graphite { didSet { save() } }

    // Week / hydration
    var weekStartsOn: Weekday = .sunday { didSet { save() } }
    var hydrationTargetOunces: Double = 200 { didSet { save() } }

    // Notifications
    var notificationsEnabled: Bool = true { didSet { save() } }
    var dailySummaryEnabled: Bool = false { didSet { save() } }
    var dailySummaryTime = TimeOfDay(hour: 8, minute: 0) { didSet { save() } }
    var beforeBedSummaryEnabled: Bool = false { didSet { save() } }
    var beforeBedSummaryTime = TimeOfDay(hour: 22, minute: 0) { didSet { save() } }

    // Security
    var appLockEnabled: Bool = false { didSet { save() } }
    var lockOnBackground: Bool = true { didSet { save() } }
    var autoLockGraceSeconds: Int = 60 { didSet { save() } }

    // Integrations (user-configurable deep links)
    var myFitnessPalURL: String = "myfitnesspal://" { didSet { save() } }
    var bibleAppURL: String = "youversion://" { didSet { save() } }

    // Onboarding
    var hasCompletedOnboarding: Bool = false { didSet { save() } }

    var hydrationGoal: HydrationGoal { HydrationGoal(target: hydrationTargetOunces, unit: .fluidOunces) }

    private func load() {
        if let raw = defaults.string(forKey: "appearance"), let v = AppearanceMode(rawValue: raw) { appearance = v }
        if let raw = defaults.string(forKey: "accent"), let v = AccentColorName(rawValue: raw) { accentColorName = v }
        if defaults.object(forKey: "weekStart") != nil { weekStartsOn = Weekday(rawValue: defaults.integer(forKey: "weekStart")) ?? .sunday }
        if defaults.object(forKey: "hydrationTarget") != nil { hydrationTargetOunces = defaults.double(forKey: "hydrationTarget") }
        if defaults.object(forKey: "notifsEnabled") != nil { notificationsEnabled = defaults.bool(forKey: "notifsEnabled") }
        dailySummaryEnabled = defaults.bool(forKey: "dailySummary")
        beforeBedSummaryEnabled = defaults.bool(forKey: "bedSummary")
        appLockEnabled = defaults.bool(forKey: "appLock")
        if defaults.object(forKey: "lockOnBg") != nil { lockOnBackground = defaults.bool(forKey: "lockOnBg") }
        if defaults.object(forKey: "grace") != nil { autoLockGraceSeconds = defaults.integer(forKey: "grace") }
        if let s = defaults.string(forKey: "mfpURL") { myFitnessPalURL = s }
        if let s = defaults.string(forKey: "bibleURL") { bibleAppURL = s }
        hasCompletedOnboarding = defaults.bool(forKey: "onboarded")
        dailySummaryTime = decodeTime("dailyTime") ?? dailySummaryTime
        beforeBedSummaryTime = decodeTime("bedTime") ?? beforeBedSummaryTime
    }

    private func save() {
        defaults.set(appearance.rawValue, forKey: "appearance")
        defaults.set(accentColorName.rawValue, forKey: "accent")
        defaults.set(weekStartsOn.rawValue, forKey: "weekStart")
        defaults.set(hydrationTargetOunces, forKey: "hydrationTarget")
        defaults.set(notificationsEnabled, forKey: "notifsEnabled")
        defaults.set(dailySummaryEnabled, forKey: "dailySummary")
        defaults.set(beforeBedSummaryEnabled, forKey: "bedSummary")
        defaults.set(appLockEnabled, forKey: "appLock")
        defaults.set(lockOnBackground, forKey: "lockOnBg")
        defaults.set(autoLockGraceSeconds, forKey: "grace")
        defaults.set(myFitnessPalURL, forKey: "mfpURL")
        defaults.set(bibleAppURL, forKey: "bibleURL")
        defaults.set(hasCompletedOnboarding, forKey: "onboarded")
        encodeTime(dailySummaryTime, "dailyTime")
        encodeTime(beforeBedSummaryTime, "bedTime")
    }

    private func decodeTime(_ key: String) -> TimeOfDay? {
        guard defaults.object(forKey: key) != nil else { return nil }
        let packed = defaults.integer(forKey: key)
        return TimeOfDay(hour: packed / 60, minute: packed % 60)
    }
    private func encodeTime(_ time: TimeOfDay, _ key: String) {
        defaults.set(time.minutesSinceMidnight, forKey: key)
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Restrained, mature accent palette (no neon).
enum AccentColorName: String, CaseIterable, Identifiable {
    case graphite, ochre, sage, slateBlue, clay
    var id: String { rawValue }
    var label: String {
        switch self {
        case .graphite: return "Graphite"
        case .ochre: return "Ochre"
        case .sage: return "Sage"
        case .slateBlue: return "Slate Blue"
        case .clay: return "Clay"
        }
    }
    var color: Color {
        switch self {
        case .graphite: return Color(red: 0.36, green: 0.38, blue: 0.42)
        case .ochre: return Color(red: 0.72, green: 0.53, blue: 0.20)
        case .sage: return Color(red: 0.42, green: 0.52, blue: 0.42)
        case .slateBlue: return Color(red: 0.34, green: 0.42, blue: 0.56)
        case .clay: return Color(red: 0.64, green: 0.42, blue: 0.36)
        }
    }
}

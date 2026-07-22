import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Opens external apps for the MyFitnessPal and Bible tasks. Uses the user-configured
/// URL scheme and gracefully falls back to a website if the app isn't installed. No
/// scraping, credentials, or automation inside third-party apps — just a link.
struct DeepLinker: Sendable {

    struct Target: Sendable {
        var primary: URL?
        var fallbackWeb: URL?
    }

    static let myFitnessPalWeb = URL(string: "https://www.myfitnesspal.com")
    static let bibleWeb = URL(string: "https://www.bible.com")

    func open(_ target: Target) {
        let url = target.primary ?? target.fallbackWeb
        guard let url else { return }
        openURL(url, fallback: target.fallbackWeb)
    }

    func openMyFitnessPal(scheme: String) {
        open(Target(primary: URL(string: scheme), fallbackWeb: Self.myFitnessPalWeb))
    }

    func openBible(scheme: String) {
        open(Target(primary: URL(string: scheme), fallbackWeb: Self.bibleWeb))
    }

    private func openURL(_ url: URL, fallback: URL?) {
        #if canImport(UIKit)
        MainActor.assumeIsolated {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success, let fallback { UIApplication.shared.open(fallback) }
            }
        }
        #elseif canImport(AppKit)
        if !NSWorkspace.shared.open(url), let fallback {
            NSWorkspace.shared.open(fallback)
        }
        #endif
    }
}

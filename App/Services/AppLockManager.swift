import Foundation
import SwiftUI
import LocalAuthentication

/// Face ID / Touch ID app lock with automatic device-passcode fallback
/// (`.deviceOwnerAuthentication`). Handles lock-on-background with a configurable
/// grace period, and drives the app-switcher privacy cover.
@MainActor
@Observable
final class AppLockManager {
    private let settings: AppSettings

    private(set) var isLocked = false
    private(set) var shouldShowPrivacyCover = false
    private(set) var lastError: String?

    private var backgroundedAt: Date?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var isBiometricsAvailable: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    var biometryTypeDescription: String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    func lockIfEnabledAtLaunch() async {
        guard settings.appLockEnabled else { isLocked = false; return }
        isLocked = true
        await authenticate()
    }

    /// Attempt authentication. On success, unlocks. On failure, stays locked so the
    /// user can retry (the lock screen shows a retry button).
    func authenticate() async {
        guard settings.appLockEnabled else { isLocked = false; return }
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            // No biometrics/passcode configured on device — don't trap the user out.
            lastError = policyError?.localizedDescription
            isLocked = false
            return
        }
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Cairn to view your routine."
            )
            isLocked = !success
            if success { lastError = nil }
        } catch {
            lastError = error.localizedDescription
            isLocked = true
        }
    }

    // MARK: - Scene phase handling

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            shouldShowPrivacyCover = true
            backgroundedAt = Date()
        case .inactive:
            // Cover content while in the app switcher.
            shouldShowPrivacyCover = settings.appLockEnabled || shouldShowPrivacyCover
        case .active:
            shouldShowPrivacyCover = false
            evaluateAutoLock()
        @unknown default:
            break
        }
    }

    private func evaluateAutoLock() {
        guard settings.appLockEnabled else { return }
        guard settings.lockOnBackground, let since = backgroundedAt else { return }
        let elapsed = Date().timeIntervalSince(since)
        if elapsed >= Double(settings.autoLockGraceSeconds) {
            isLocked = true
            Task { await authenticate() }
        }
        backgroundedAt = nil
    }

    /// Called when the user turns the lock on in Settings, to verify it works.
    func lockNow() {
        guard settings.appLockEnabled else { return }
        isLocked = true
        Task { await authenticate() }
    }
}

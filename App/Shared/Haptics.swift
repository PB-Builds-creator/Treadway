import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Restrained haptic feedback. No-op where unsupported (macOS). Respects the
/// system: iOS silences these automatically when Reduce Motion / low-power apply.
enum Haptics {
    @MainActor static func tap() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    @MainActor static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

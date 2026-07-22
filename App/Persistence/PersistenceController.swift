import Foundation
import SwiftData

/// Builds the shared `ModelContainer`. Uses CloudKit private-database mirroring when
/// available, and falls back to a local-only store if iCloud/CloudKit can't be
/// configured (e.g. not signed in), so the app is always usable offline.
enum PersistenceController {

    static let schema = Schema([
        TaskEntity.self,
        CompletionEntity.self,
        HydrationEntryEntity.self,
        CategoryEntity.self
    ])

    /// The CloudKit container id must match the entitlement (see README → iCloud).
    static let cloudKitContainerID = "iCloud.com.paxton.cairn"
    /// Shared app group so the app and the widget/intents extension use ONE local
    /// store (in addition to CloudKit), avoiding a divergent second database.
    static let appGroupID = "group.com.paxton.cairn"

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        // 1) Preferred: app-group-shared, CloudKit-backed private database.
        //
        // Gated behind LOCAL_ONLY: CloudKit mirroring traps *asynchronously* if the
        // process lacks the iCloud entitlement (a `try?` can't catch it), so the
        // free/local Mac build must never request it. The full multiplatform build
        // (with entitlements) leaves LOCAL_ONLY undefined and uses this path.
        #if !LOCAL_ONLY
        if !inMemory {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
                return container
            }
        }
        #endif

        // 2) Local-only store (no iCloud). App remains fully functional offline.
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // 3) Last resort: in-memory, so the app never fails to launch.
        // (A user-visible banner surfaces this state from AppEnvironment.)
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [memoryConfig])
        } catch {
            fatalError("Unable to create even an in-memory ModelContainer: \(error)")
        }
    }
}

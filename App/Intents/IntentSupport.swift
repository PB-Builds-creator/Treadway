import Foundation
import AppIntents
import SwiftData
import CairnCore

/// Shared helpers for App Intents. Intents may run in a separate process (widgets,
/// Shortcuts), so each builds its own container/store via the shared configuration.
enum IntentSupport {
    @MainActor
    static func makeStore() -> Store {
        Store(modelContainer: PersistenceController.makeContainer())
    }

    static var currentDay: CalendarDay { MountainTime.day(for: Date()) }
}

/// Exposes tasks to Shortcuts/Siri for the "Complete task" intent.
struct TaskAppEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task"
    static let defaultQuery = TaskEntityQuery()

    var id: UUID
    var title: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct TaskEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [TaskAppEntity] {
        let all = try await IntentSupport.makeStore().allTasks()
        return all.filter { identifiers.contains($0.id) }.map { TaskAppEntity(id: $0.id, title: $0.title) }
    }

    @MainActor
    func suggestedEntities() async throws -> [TaskAppEntity] {
        let engine = RecurrenceEngine()
        let day = IntentSupport.currentDay
        let all = try await IntentSupport.makeStore().allTasks()
        return all.filter { !$0.isArchived && engine.occurs($0.schedule, on: day) }
            .map { TaskAppEntity(id: $0.id, title: $0.title) }
    }
}

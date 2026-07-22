import Foundation

/// Human-readable JSON snapshot of all app data, for export/import and backup.
/// Versioned so future schema changes can migrate cleanly.
public struct DataArchive: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var timeZoneIdentifier: String
    public var categories: [TaskCategory]
    public var tasks: [TaskModel]
    public var completions: [CompletionRecord]
    public var hydrationDays: [HydrationDay]
    public var hydrationGoal: HydrationGoal

    public init(
        version: Int = DataArchive.currentVersion,
        exportedAt: Date,
        timeZoneIdentifier: String = MountainTime.timeZone.identifier,
        categories: [TaskCategory],
        tasks: [TaskModel],
        completions: [CompletionRecord],
        hydrationDays: [HydrationDay],
        hydrationGoal: HydrationGoal
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.categories = categories
        self.tasks = tasks
        self.completions = completions
        self.hydrationDays = hydrationDays
        self.hydrationGoal = hydrationGoal
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> DataArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(DataArchive.self, from: data)
        guard archive.version <= currentVersion else {
            throw ArchiveError.unsupportedVersion(archive.version)
        }
        return archive
    }

    public enum ArchiveError: Error, LocalizedError {
        case unsupportedVersion(Int)
        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let v):
                return "This backup was created by a newer version of the app (format \(v))."
            }
        }
    }
}

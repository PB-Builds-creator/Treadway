import Foundation

/// A day of the week, decoupled from `Calendar`'s 1-based Gregorian indexing.
public enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    /// Build from `Calendar`'s `.weekday` component (1 = Sunday ... 7 = Saturday).
    public init(gregorianComponent: Int) {
        // Clamp defensively so an out-of-range component never traps.
        let clamped = ((gregorianComponent - 1) % 7 + 7) % 7 + 1
        self = Weekday(rawValue: clamped) ?? .sunday
    }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Full localized-ish name (kept simple; UI uses `DateFormatter` for display).
    public var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    public var shortName: String { String(fullName.prefix(3)) }

    /// The five days the Asia Trading Session runs (Sun–Thu).
    public static let sundayThroughThursday: Set<Weekday> =
        [.sunday, .monday, .tuesday, .wednesday, .thursday]
}

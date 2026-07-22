import Foundation

/// Immutable daily hydration state plus pure operations. Stored canonically in
/// milliliters so the display unit (oz by default) can change without data loss.
public struct HydrationDay: Hashable, Codable, Sendable {
    public var day: CalendarDay
    /// Canonical stored volume, always in milliliters, never negative.
    public private(set) var milliliters: Double
    /// Individual entries, kept so a mistaken entry can be corrected/removed.
    public private(set) var entries: [Entry]

    public struct Entry: Identifiable, Hashable, Codable, Sendable {
        public var id: UUID
        public var milliliters: Double
        public var timestamp: Date
        public init(id: UUID = UUID(), milliliters: Double, timestamp: Date) {
            self.id = id
            self.milliliters = milliliters
            self.timestamp = timestamp
        }
    }

    public init(day: CalendarDay, entries: [Entry] = []) {
        self.day = day
        self.entries = entries
        self.milliliters = max(0, entries.reduce(0) { $0 + $1.milliliters })
    }

    /// Add a positive amount in the given unit. Non-positive amounts are ignored,
    /// which prevents accidental negative totals from add controls.
    public func adding(_ amount: Double, unit: MeasurementUnit, at timestamp: Date) -> HydrationDay {
        guard amount > 0 else { return self }
        let ml = amount * unit.toMilliliters
        var copy = self
        copy.entries.append(Entry(milliliters: ml, timestamp: timestamp))
        copy.milliliters = max(0, copy.milliliters + ml)
        return copy
    }

    /// Remove a specific entry (correcting a mistake). Total can never go negative.
    public func removingEntry(_ id: UUID) -> HydrationDay {
        var copy = self
        copy.entries.removeAll { $0.id == id }
        copy.milliliters = max(0, copy.entries.reduce(0) { $0 + $1.milliliters })
        return copy
    }

    /// Directly set the total (e.g. user typed a corrected value). Clamped at 0.
    public func settingTotal(_ amount: Double, unit: MeasurementUnit, at timestamp: Date) -> HydrationDay {
        let ml = max(0, amount * unit.toMilliliters)
        return HydrationDay(day: day, entries: [Entry(milliliters: ml, timestamp: timestamp)])
    }

    /// Current total expressed in the requested display unit.
    public func total(in unit: MeasurementUnit) -> Double {
        milliliters / unit.toMilliliters
    }
}

/// A hydration goal + progress calculation, independent of any particular day.
public struct HydrationGoal: Hashable, Codable, Sendable {
    public var target: Double
    public var unit: MeasurementUnit

    /// Default goal: 200 fluid ounces.
    public static let `default` = HydrationGoal(target: 200, unit: .fluidOunces)

    public init(target: Double, unit: MeasurementUnit = .fluidOunces) {
        self.target = max(1, target)   // guard against divide-by-zero / nonsense goals
        self.unit = unit
    }

    /// Progress in 0...1 (clamped) for a given day's intake.
    public func fraction(for day: HydrationDay) -> Double {
        let current = day.total(in: unit)
        return min(max(current / target, 0), 1)
    }

    public func isMet(for day: HydrationDay) -> Bool {
        day.total(in: unit) >= target
    }

    /// "120 / 200 oz"
    public func progressLabel(for day: HydrationDay) -> String {
        let current = day.total(in: unit)
        return "\(current.trimmedString) / \(target.trimmedString) \(unit.abbreviation)"
    }
}

extension Double {
    /// Render without trailing ".0" for whole numbers; one decimal otherwise.
    var trimmedString: String {
        if rounded() == self { return String(Int(self)) }
        return String(format: "%.1f", self)
    }
}

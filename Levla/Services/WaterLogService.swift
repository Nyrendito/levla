import Foundation
import Observation

/// Simple device-local water tracker — UserDefaults-backed, resets at the
/// local-calendar day rollover. Goal default is 2,000 ml (≈8 cups, the
/// commonly-cited daily intake target for adults).
///
/// Kept off the server for v1 because it's a high-frequency tap target
/// and not worth a Supabase round-trip on every +250 ml.
@MainActor
@Observable
final class WaterLogService {
    private let stepMl = 250          // one cup per tap
    private(set) var ml: Int = 0
    private(set) var dayKey: String = ""

    var goalMl: Int = 2_000

    private static let mlKey = "water.ml"
    private static let dayKeyKey = "water.day"

    init() {
        refreshIfDayChanged()
    }

    /// Sync against today's calendar day; resets to 0 if the day changed
    /// since last write.
    func refreshIfDayChanged() {
        let today = Self.todayKey()
        let stored = UserDefaults.standard.string(forKey: Self.dayKeyKey)
        if stored == today {
            ml = UserDefaults.standard.integer(forKey: Self.mlKey)
            dayKey = today
        } else {
            ml = 0
            dayKey = today
            UserDefaults.standard.set(0, forKey: Self.mlKey)
            UserDefaults.standard.set(today, forKey: Self.dayKeyKey)
        }
    }

    func add() {
        ml = min(5_000, ml + stepMl)
        persist()
    }

    func subtract() {
        ml = max(0, ml - stepMl)
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(ml, forKey: Self.mlKey)
        UserDefaults.standard.set(dayKey, forKey: Self.dayKeyKey)
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}

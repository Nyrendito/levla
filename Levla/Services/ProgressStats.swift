import Foundation

/// Pure computation over cooked_entries + fridge + profile to power the
/// Progress tab. Doesn't touch the network — fed by the services that
/// already cache the underlying data.
enum ProgressStats {

    // MARK: - Streak

    /// Days you cooked from your fridge — consecutive days, looking back
    /// from today. A "cooked-from-fridge" day is any day with at least one
    /// CookedEntry whose recipe_slug doesn't start with "snap-" (snap-meals
    /// from the Log-a-meal flow are not fridge-driven cooking).
    static func cookedFromFridgeStreak(entries: [CookedEntry], now: Date = Date()) -> Int {
        let cal = Calendar.current
        let fridgeDays = Set(
            entries
                .filter { !$0.recipeSlug.hasPrefix("snap-") }
                .map { cal.startOfDay(for: $0.cookedAt) }
        )
        var streak = 0
        var cursor = cal.startOfDay(for: now)
        while fridgeDays.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// 7-day strip used by the Streak card. Returns `[true, false, ...]` for
    /// the past 7 days (oldest first → today last). A "true" means at least
    /// one cooked-from-fridge entry that day.
    static func cookedFromFridgeWeekDots(entries: [CookedEntry], now: Date = Date()) -> [Bool] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let fridgeDays = Set(
            entries
                .filter { !$0.recipeSlug.hasPrefix("snap-") }
                .map { cal.startOfDay(for: $0.cookedAt) }
        )
        return (0..<7).reversed().map { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return false }
            return fridgeDays.contains(day)
        }
    }

    // MARK: - Weekly calorie chart

    struct DayTotals: Hashable, Sendable {
        let date: Date
        let kcal: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    /// Day-by-day totals across the 7 calendar days ending today. Empty days
    /// return zeros so the chart can render a flat baseline.
    static func weeklyDailyTotals(entries: [CookedEntry], weekOffset: Int = 0, now: Date = Date()) -> [DayTotals] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let weekEnd = cal.date(byAdding: .day, value: -7 * weekOffset, to: today) else { return [] }
        return (0..<7).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: weekEnd) else { return nil }
            let dayEntries = entries.filter { cal.isDate($0.cookedAt, inSameDayAs: day) }
            return DayTotals(
                date: day,
                kcal:    dayEntries.reduce(0) { $0 + $1.kcal },
                protein: dayEntries.reduce(0) { $0 + $1.protein },
                carbs:   dayEntries.reduce(0) { $0 + $1.carbs },
                fat:     dayEntries.reduce(0) { $0 + $1.fat }
            )
        }
    }

    /// Sum kcal across a week.
    static func weeklyKcal(entries: [CookedEntry], weekOffset: Int = 0, now: Date = Date()) -> Int {
        weeklyDailyTotals(entries: entries, weekOffset: weekOffset, now: now).reduce(0) { $0 + $1.kcal }
    }

    /// Average kcal per day with at least one entry. Useful when the week
    /// isn't full yet.
    static func weeklyAvgKcal(entries: [CookedEntry], weekOffset: Int = 0, now: Date = Date()) -> Int {
        let days = weeklyDailyTotals(entries: entries, weekOffset: weekOffset, now: now)
        let active = days.filter { $0.kcal > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.kcal } / active.count
    }

    // MARK: - Macro hit-rate

    /// For each of the 7 days in the window, did the user hit their daily
    /// macro goal? Returns ratios like 4/7 etc. A day with zero entries
    /// counts as a miss (not abstained) — Cal AI is similarly strict.
    struct MacroHitRate: Hashable, Sendable {
        let kcalInRange: Int     // days within ±10% of goal
        let proteinHit:  Int     // days at or above protein goal
        let total:       Int     // always 7
    }

    static func macroHitRate(
        entries: [CookedEntry],
        weekOffset: Int = 0,
        kcalGoal: Int?,
        proteinGoal: Int?,
        now: Date = Date()
    ) -> MacroHitRate {
        let days = weeklyDailyTotals(entries: entries, weekOffset: weekOffset, now: now)
        var kcalDays = 0
        var proteinDays = 0
        if let kcalGoal {
            let lower = Double(kcalGoal) * 0.90
            let upper = Double(kcalGoal) * 1.10
            kcalDays = days.filter { d in
                let k = Double(d.kcal)
                return k >= lower && k <= upper
            }.count
        }
        if let proteinGoal {
            proteinDays = days.filter { $0.protein >= proteinGoal }.count
        }
        return MacroHitRate(kcalInRange: kcalDays, proteinHit: proteinDays, total: 7)
    }

    // MARK: - From your fridge

    struct FridgeUsage: Hashable, Sendable {
        let itemsScanned: Int     // fridge items added in window
        let mealsCooked:  Int     // non-snap cooked entries in window
    }

    /// Items scanned vs meals cooked from the fridge for the current week.
    /// Snap-meal entries are excluded because they're not fridge-derived.
    static func fridgeUsage(
        fridgeItems: [FoodItem],
        cookedEntries: [CookedEntry],
        days: Int = 7,
        now: Date = Date()
    ) -> FridgeUsage {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -days, to: now) else {
            return FridgeUsage(itemsScanned: 0, mealsCooked: 0)
        }
        let scanned = fridgeItems.filter { $0.addedAt >= cutoff }.count
        let cooked = cookedEntries
            .filter { !$0.recipeSlug.hasPrefix("snap-") }
            .filter { $0.cookedAt >= cutoff }
            .count
        return FridgeUsage(itemsScanned: scanned, mealsCooked: cooked)
    }

    // MARK: - Weight trend

    struct WeightTrendPoint: Hashable, Sendable {
        let date: Date
        let weightKg: Double
    }

    /// Decimate weight logs to one point per day, then keep only the points
    /// that fall in the requested window. Used to feed the Goal Progress
    /// line chart.
    static func weightTrend(logs: [WeightLog], windowDays: Int, now: Date = Date()) -> [WeightTrendPoint] {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -windowDays, to: now) else { return [] }
        // Keep only one log per day — the latest of that day.
        let inWindow = logs.filter { $0.loggedAt >= cutoff }
        let byDay = Dictionary(grouping: inWindow) { cal.startOfDay(for: $0.loggedAt) }
        return byDay
            .map { (day, items) -> WeightTrendPoint in
                let latest = items.max(by: { $0.loggedAt < $1.loggedAt })!
                return WeightTrendPoint(date: day, weightKg: latest.weightKg)
            }
            .sorted(by: { $0.date < $1.date })
    }

    /// Percent toward the goal weight, capped to 0…100. nil if either side
    /// is missing.
    static func goalProgress(logs: [WeightLog], startWeightKg: Double?, goalWeightKg: Double?) -> Int? {
        guard let latest = logs.max(by: { $0.loggedAt < $1.loggedAt })?.weightKg,
              let start = startWeightKg ?? logs.min(by: { $0.loggedAt < $1.loggedAt })?.weightKg,
              let goal = goalWeightKg, start != goal else { return nil }
        let total = goal - start
        let actual = latest - start
        let ratio = actual / total
        let pct = Int((max(0, min(1, ratio)) * 100).rounded())
        return pct
    }
}

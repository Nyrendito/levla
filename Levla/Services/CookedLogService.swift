import Foundation
import Supabase

/// Today's macro tracker. Driven by "Start cooking" taps — each one inserts
/// a `cooked_entries` row server-side; we sum them per local-calendar-day
/// to power the Cal-AI-style macros bar on Home.
@MainActor
@Observable
final class CookedLogService {
    private(set) var todayEntries: [CookedEntry] = []
    /// Last ~120 days of entries, used by the Progress tab for streaks,
    /// weekly charts, and macro hit-rate.
    private(set) var historyEntries: [CookedEntry] = []
    private(set) var isLoading = false

    private let supabase = LevlaSupabase.shared
    private var offlineStore: [CookedEntry] = []

    // MARK: - Today's totals

    /// Entries that actually fall on the current local-calendar day. We
    /// filter at the property level rather than trusting `todayEntries`
    /// blindly — if the clock rolled past midnight while the app was open
    /// and we haven't refetched yet, this guarantees yesterday's entries
    /// don't keep counting toward today's macros.
    private var filteredToday: [CookedEntry] {
        let cal = Calendar.current
        return todayEntries.filter { cal.isDateInToday($0.cookedAt) }
    }

    var todayKcal:    Int { filteredToday.reduce(0) { $0 + $1.kcal } }
    var todayProtein: Int { filteredToday.reduce(0) { $0 + $1.protein } }
    var todayCarbs:   Int { filteredToday.reduce(0) { $0 + $1.carbs } }
    var todayFat:     Int { filteredToday.reduce(0) { $0 + $1.fat } }

    /// Micros — nil-coalesced because older rows logged before we tracked
    /// them have null columns.
    var todayFiber:   Int { filteredToday.reduce(0) { $0 + ($1.fiber  ?? 0) } }
    var todaySugar:   Int { filteredToday.reduce(0) { $0 + ($1.sugar  ?? 0) } }
    var todaySodium:  Int { filteredToday.reduce(0) { $0 + ($1.sodium ?? 0) } }

    var hasAnyToday: Bool { !filteredToday.isEmpty }

    /// The local-calendar day for which `todayEntries` was last fetched.
    /// Used to decide whether a foreground / day-change event needs to
    /// trigger a refetch.
    private(set) var loadedDay: Date? = nil

    // MARK: - Reload + log

    /// Pulls today's cooked entries for the user. Cheap — a single index scan.
    func reloadToday(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())

        if supabase.isOffline {
            todayEntries = offlineStore.filter { isToday($0.cookedAt) }
            loadedDay = startOfDay
            return
        }

        guard let client = supabase.client else { return }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startISO = iso.string(from: startOfDay)

        do {
            let rows: [CookedEntry] = try await client
                .from("cooked_entries")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("cooked_at", value: startISO)
                .order("cooked_at", ascending: false)
                .execute()
                .value
            todayEntries = rows
            loadedDay = startOfDay
        } catch {
            // soft fail — show whatever we already had
        }
    }

    /// Cheap check: if the local calendar day has changed since the last
    /// reload, trigger a refetch. Called on app-foreground + on the
    /// `.NSCalendarDayChanged` notification so the home macros zero out at
    /// midnight even when the app stays open across the rollover.
    func refreshIfDayChanged(userId: UUID) async {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = loadedDay, Calendar.current.isDate(last, inSameDayAs: today) {
            return
        }
        await reloadToday(userId: userId)
    }

    /// Pulls the last ~120 days of entries. Backs the Progress tab.
    /// Cheap on a per-user index.
    func reloadHistory(userId: UUID, days: Int = 120) async {
        if supabase.isOffline {
            historyEntries = offlineStore
            return
        }
        guard let client = supabase.client else { return }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let cutoffISO = iso.string(from: cutoff)

        do {
            let rows: [CookedEntry] = try await client
                .from("cooked_entries")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("cooked_at", value: cutoffISO)
                .order("cooked_at", ascending: false)
                .execute()
                .value
            historyEntries = rows
        } catch {
            // soft fail
        }
    }

    /// Record that the user just started cooking a recipe with N servings.
    /// Macros are multiplied by servings before logging.
    func log(recipe: Recipe, servings: Int, userId: UUID) async {
        let entry = CookedEntry(
            userId: userId,
            recipeSlug: recipe.slug,
            recipeTitle: recipe.title,
            servings: servings,
            kcal:    recipe.kcal    * servings,
            protein: recipe.protein * servings,
            carbs:   recipe.carbs   * servings,
            fat:     recipe.fat     * servings,
            cookedAt: Date()
        )

        if supabase.isOffline {
            offlineStore.append(entry)
            todayEntries = offlineStore.filter { isToday($0.cookedAt) }
            return
        }

        guard let client = supabase.client else { return }
        do {
            try await client.from("cooked_entries").insert(entry).execute()
            await reloadToday(userId: userId)
        } catch {
            // soft fail
        }
    }

    /// Log a Cal-AI-style snapped meal. No recipe slug — we use the title the
    /// vision model returned and a stable synthetic slug so the row obeys the
    /// schema's NOT NULL.
    func logSnapped(meal: AnalyzedMeal, userId: UUID) async {
        let synthSlug = "snap-" + meal.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let entry = CookedEntry(
            userId: userId,
            recipeSlug: synthSlug.isEmpty ? "snap-meal" : synthSlug,
            recipeTitle: meal.name,
            servings: 1,
            kcal:    meal.kcal,
            protein: meal.protein,
            carbs:   meal.carbs,
            fat:     meal.fat,
            fiber:   meal.fiber,
            sugar:   meal.sugar,
            sodium:  meal.sodium,
            cookedAt: Date()
        )

        if supabase.isOffline {
            offlineStore.append(entry)
            todayEntries = offlineStore.filter { isToday($0.cookedAt) }
            return
        }

        guard let client = supabase.client else { return }
        do {
            try await client.from("cooked_entries").insert(entry).execute()
            await reloadToday(userId: userId)
        } catch {
            // soft fail
        }
    }

    // MARK: - Helpers

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

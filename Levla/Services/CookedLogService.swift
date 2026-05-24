import Foundation
import Supabase

/// Today's macro tracker. Driven by "Start cooking" taps — each one inserts
/// a `cooked_entries` row server-side; we sum them per local-calendar-day
/// to power the Cal-AI-style macros bar on Home.
@MainActor
@Observable
final class CookedLogService {
    private(set) var todayEntries: [CookedEntry] = []
    private(set) var isLoading = false

    private let supabase = LevlaSupabase.shared
    private var offlineStore: [CookedEntry] = []

    // MARK: - Today's totals

    var todayKcal:    Int { todayEntries.reduce(0) { $0 + $1.kcal } }
    var todayProtein: Int { todayEntries.reduce(0) { $0 + $1.protein } }
    var todayCarbs:   Int { todayEntries.reduce(0) { $0 + $1.carbs } }
    var todayFat:     Int { todayEntries.reduce(0) { $0 + $1.fat } }

    var hasAnyToday: Bool { !todayEntries.isEmpty }

    // MARK: - Reload + log

    /// Pulls today's cooked entries for the user. Cheap — a single index scan.
    func reloadToday(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        if supabase.isOffline {
            todayEntries = offlineStore.filter { isToday($0.cookedAt) }
            return
        }

        guard let client = supabase.client else { return }

        let startOfDay = Calendar.current.startOfDay(for: Date())
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
        } catch {
            // soft fail — show whatever we already had
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

    // MARK: - Helpers

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

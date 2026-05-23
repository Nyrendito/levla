import Foundation
import Supabase

/// Loads recipe ideas from the `suggest-recipes` Edge Function (GPT-4.1-mini).
/// Caches the result in memory keyed by a stable hash of the fridge contents,
/// so we don't re-call OpenAI on every render. Falls back to `SeedData.recipes`
/// in offline mode or if the call fails.
@MainActor
@Observable
final class RecipeService {
    private(set) var recipes: [Recipe] = SeedData.recipes
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var lastLoadedAt: Date?

    private var cachedKey: String? = nil
    private let supabase = LevlaSupabase.shared

    /// Hash the fridge state in a way that's deterministic and ignores
    /// ordering — same items in different order shouldn't re-fetch.
    private func fridgeKey(_ items: [FoodItem]) -> String {
        items
            .map { "\($0.foodKey):\($0.status.rawValue):\($0.daysLeft)" }
            .sorted()
            .joined(separator: "|")
    }

    /// Reload recipe ideas for the given fridge. Skips network if the fridge
    /// hasn't changed since the last successful fetch.
    func reload(for items: [FoodItem], force: Bool = false) async {
        let key = fridgeKey(items)
        if !force, key == cachedKey, !recipes.isEmpty { return }

        if supabase.isOffline {
            recipes = SeedData.recipes
            cachedKey = key
            return
        }
        guard let client = supabase.client else { return }

        // Need a valid session JWT for the Edge Function (verify_jwt = true).
        guard let session = try? await client.auth.session, !session.accessToken.isEmpty else {
            // Not signed in yet — keep seed recipes around.
            recipes = SeedData.recipes
            return
        }

        isLoading = true
        defer { isLoading = false }

        let payload = SuggestRequest(fridge: items.map(WireItem.init))

        do {
            let data: Data = try await client.functions.invoke(
                "suggest-recipes",
                options: .init(body: payload)
            )
            let decoded = try JSONDecoder().decode(SuggestResponse.self, from: data)
            let mapped = decoded.recipes.compactMap { $0.toRecipe() }
            if !mapped.isEmpty {
                recipes = mapped
                cachedKey = key
                lastLoadedAt = Date()
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
            // Keep whatever we had before — better to show stale recipes than nothing.
        }
    }

    // MARK: - Wire types

    private struct SuggestRequest: Encodable {
        let fridge: [WireItem]
    }

    private struct WireItem: Encodable {
        let foodKey: String
        let name: String
        let qty: String
        let daysLeft: Int
        let status: String

        init(_ item: FoodItem) {
            self.foodKey = item.foodKey
            self.name = item.name
            self.qty = item.qty
            self.daysLeft = item.daysLeft
            self.status = item.status.rawValue
        }
    }

    private struct SuggestResponse: Decodable {
        let recipes: [LLMRecipe]
    }

    private struct LLMRecipe: Decodable {
        let slug: String
        let title: String
        let subtitle: String?
        let timeMinutes: Int
        let kcal: Int
        let protein: Int
        let carbs: Int?
        let difficulty: String
        let uses: [String]
        let why: String?
        let colorHex: String
        let accentHex: String
        let tags: [String]
        let ingredients: [LLMIngredient]
        let steps: [String]

        func toRecipe() -> Recipe? {
            Recipe(
                id: UUID(),
                slug: slug,
                title: title,
                subtitle: subtitle ?? "",
                timeMinutes: timeMinutes,
                kcal: kcal,
                protein: protein,
                carbs: carbs ?? 0,
                difficulty: difficulty,
                matchPct: 0,                // recomputed locally via RecipeMatcher
                missing: [],
                uses: uses,
                why: why ?? "",
                colorHex: colorHex,
                accentHex: accentHex,
                tags: tags,
                ingredients: ingredients.map(\.toIngredient),
                steps: steps
            )
        }
    }

    private struct LLMIngredient: Decodable {
        let foodKey: String
        let name: String
        let amount: String

        var toIngredient: RecipeIngredient {
            RecipeIngredient(
                foodKey: foodKey,
                name: name,
                amount: amount,
                have: false,
                useSoon: false,
                low: false
            )
        }
    }
}

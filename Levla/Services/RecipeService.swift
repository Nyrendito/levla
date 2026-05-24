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
            // Bypass the SDK's auto-decode so we can do permissive parsing
            // ourselves. We hand a closure that returns the raw bytes.
            let data = try await client.functions.invoke("suggest-recipes",
                                                         options: .init(body: payload)) {
                (data: Data, response: HTTPURLResponse) -> Data in
                if 200..<300 ~= response.statusCode { return data }
                throw FunctionsError.httpError(code: response.statusCode, data: data)
            }
            let mapped = parseRecipes(from: data)
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

    /// Parses the suggest-recipes response permissively. Accepts:
    /// - camelCase or snake_case keys
    /// - missing fields (filled with sensible defaults)
    /// - numeric fields delivered as strings
    /// Returns whichever recipes parsed successfully.
    private func parseRecipes(from data: Data) -> [Recipe] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let raws = (root["recipes"] as? [Any]) ?? (root["data"] as? [Any]) ?? []

        return raws.compactMap { raw -> Recipe? in
            guard let r = raw as? [String: Any] else { return nil }

            func str(_ keys: String...) -> String? {
                for k in keys {
                    if let v = r[k] as? String { return v }
                    if let n = r[k] as? Double { return String(n) }
                    if let n = r[k] as? Int    { return String(n) }
                }
                return nil
            }
            func int(_ keys: String...) -> Int? {
                for k in keys {
                    if let v = r[k] as? Int    { return v }
                    if let v = r[k] as? Double { return Int(v) }
                    if let s = r[k] as? String, let v = Int(s) { return v }
                }
                return nil
            }
            func arrStr(_ keys: String...) -> [String] {
                for k in keys {
                    if let arr = r[k] as? [String] { return arr }
                    if let arr = r[k] as? [Any] {
                        return arr.compactMap { $0 as? String }
                    }
                }
                return []
            }
            func arrDict(_ keys: String...) -> [[String: Any]] {
                for k in keys {
                    if let arr = r[k] as? [[String: Any]] { return arr }
                }
                return []
            }

            let title = str("title", "name") ?? "Untitled recipe"
            let slug = str("slug") ?? title
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: ",", with: "")

            let ingredientsRaw = arrDict("ingredients")
            let ingredients = ingredientsRaw.map { ing -> RecipeIngredient in
                let foodKey = (ing["foodKey"] as? String)
                    ?? (ing["food_key"] as? String)
                    ?? (ing["key"] as? String)
                    ?? "milk"
                return RecipeIngredient(
                    foodKey: foodKey,
                    name: (ing["name"] as? String) ?? "Ingredient",
                    amount: (ing["amount"] as? String) ?? (ing["qty"] as? String) ?? "1",
                    have: false, useSoon: false, low: false
                )
            }

            let mealTypeRaw = (str("mealType", "meal_type", "meal") ?? "dinner").lowercased()
            let mealType = MealType(rawValue: mealTypeRaw) ?? .dinner

            return Recipe(
                id: UUID(),
                slug: slug,
                title: title,
                subtitle: str("subtitle", "tagline") ?? "",
                timeMinutes: int("timeMinutes", "time_minutes", "time", "minutes") ?? 20,
                kcal: int("kcal", "calories", "energy") ?? 400,
                protein: int("protein", "protein_g") ?? 20,
                carbs: int("carbs", "carbs_g") ?? 30,
                fat: int("fat", "fat_g") ?? 15,
                mealType: mealType,
                difficulty: str("difficulty", "level") ?? "Easy",
                matchPct: 0,
                missing: [],
                uses: arrStr("uses", "uses_food_keys"),
                why: str("why", "reason") ?? "",
                colorHex: str("colorHex", "color_hex", "color") ?? "F3D6C6",
                accentHex: str("accentHex", "accent_hex", "accent") ?? "C9543C",
                tags: arrStr("tags"),
                ingredients: ingredients,
                steps: arrStr("steps", "instructions")
            )
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

}

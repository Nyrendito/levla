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

    /// Hash the fridge state + profile in a way that's deterministic and
    /// ignores ordering. Profile fields go into the key so swapping goals or
    /// updating weight re-runs the suggestion.
    private func cacheKey(items: [FoodItem], profile: Profile?) -> String {
        let fridgeParts: [String] = items.map { item in
            "\(item.foodKey):\(item.status.rawValue):\(item.daysLeft)"
        }
        let fridgePart: String = fridgeParts.sorted().joined(separator: "|")

        let profilePart: String
        if let p = profile {
            let goalStr = p.goal?.rawValue ?? "-"
            let actStr  = p.activityLevel?.rawValue ?? "-"
            let sexStr  = p.sex?.rawValue ?? "-"
            let kcalStr = p.dailyKcalGoal.map(String.init) ?? "-"
            let protStr = p.dailyProteinGoal.map(String.init) ?? "-"
            let dietStr = p.dietaryPrefs.sorted().joined(separator: ",")
            profilePart = [goalStr, actStr, sexStr, kcalStr, protStr, dietStr]
                .joined(separator: ":")
        } else {
            profilePart = "no-profile"
        }
        return fridgePart + "##" + profilePart
    }

    /// Reload recipe ideas for the given fridge + profile. Skips network if
    /// neither has changed since the last successful fetch.
    func reload(for items: [FoodItem], profile: Profile? = nil, force: Bool = false) async {
        let key = cacheKey(items: items, profile: profile)
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

        let payload = SuggestRequest(
            fridge: items.map(WireItem.init),
            profile: profile.map(WireProfile.init)
        )

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
                // Fire-and-forget background pre-warm so the recipe hero
                // images are ready by the time the user swipes to them.
                // ImageCacheService dedupes in-flight requests, so calling
                // this is cheap even if the orb's .task also runs.
                Task.detached { [recipes = mapped] in
                    for recipe in recipes {
                        _ = await ImageCacheService.shared.imageURL(
                            kind: .recipe,
                            key: recipe.slug,
                            title: recipe.title,
                            uses: recipe.uses
                        )
                    }
                }
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
    /// Returns whichever recipes parsed successfully. Slugs are deduped so
    /// no two recipes in the same batch share an image cache key (the LLM
    /// occasionally produces near-identical slugs and the Cook deck would
    /// then show the same hero photo on multiple cards).
    private func parseRecipes(from data: Data) -> [Recipe] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }
        let raws = (root["recipes"] as? [Any]) ?? (root["data"] as? [Any]) ?? []

        var seenSlugs = Set<String>()
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
            let rawSlug = str("slug") ?? title
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: ",", with: "")
            // Dedup: if we've already seen this slug, suffix with -2, -3, ...
            var slug = rawSlug
            var n = 2
            while seenSlugs.contains(slug) {
                slug = "\(rawSlug)-\(n)"
                n += 1
            }
            seenSlugs.insert(slug)

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
        let profile: WireProfile?
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

    /// What the suggest-recipes Edge Function expects in `profile`:
    /// only the fields it actually uses to tailor macros + cuisine.
    private struct WireProfile: Encodable {
        let sex: String?
        let age: Int?
        let heightCm: Int?
        let weightKg: Double?
        let goal: String?
        let activityLevel: String?
        let dailyKcalGoal: Int?
        let dailyProteinGoal: Int?
        let dietaryPrefs: [String]

        init(_ p: Profile) {
            self.sex = p.sex?.rawValue
            self.age = p.age
            self.heightCm = p.heightCm
            self.weightKg = p.weightKg
            self.goal = p.goal?.rawValue
            self.activityLevel = p.activityLevel?.rawValue
            self.dailyKcalGoal = p.dailyKcalGoal
            self.dailyProteinGoal = p.dailyProteinGoal
            self.dietaryPrefs = p.dietaryPrefs
        }
    }

}

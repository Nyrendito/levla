import Foundation

/// Per-ingredient state as it relates to the user's current fridge.
enum IngredientState {
    case have       // present, not expiring soon, not low
    case useSoon    // present but expiring within 3 days
    case low        // present but flagged low-stock
    case toBuy      // not in fridge
}

/// A Recipe enriched with live data about the user's actual fridge.
struct RecipeMatch: Identifiable, Hashable {
    var id: UUID { recipe.id }
    let recipe: Recipe
    let matchPct: Int                  // 0…100, recomputed from real inventory
    let missingIngredients: [RecipeIngredient]
    let useSoonIngredients: [RecipeIngredient]
    let stateByKey: [String: IngredientState]

    func state(for ingredient: RecipeIngredient) -> IngredientState {
        stateByKey[ingredient.foodKey] ?? .toBuy
    }

    /// Ingredient list with the static `have/useSoon/low` flags swapped for
    /// what we just computed against the fridge.
    var ingredients: [RecipeIngredient] {
        recipe.ingredients.map { ing in
            switch state(for: ing) {
            case .have:    return ing.with(have: true,  useSoon: false, low: false)
            case .useSoon: return ing.with(have: true,  useSoon: true,  low: false)
            case .low:     return ing.with(have: true,  useSoon: false, low: true)
            case .toBuy:   return ing.with(have: false, useSoon: false, low: false)
            }
        }
    }
}

enum RecipeMatcher {
    /// Recompute everything a Recipe says about availability from the user's
    /// current fridge.
    static func match(recipe: Recipe, fridge: [FoodItem]) -> RecipeMatch {
        let fridgeKeys = Set(fridge.map(\.foodKey))
        let soonKeys: Set<String> = Set(
            fridge.filter { $0.status == .today || $0.status == .soon }.map(\.foodKey)
        )
        let lowKeys: Set<String> = Set(fridge.filter { $0.status == .low }.map(\.foodKey))

        // Source of truth for "what does this recipe need?" is recipe.ingredients
        // (more granular than recipe.uses, which is just a tag list for art).
        let neededKeys = recipe.ingredients.isEmpty
            ? recipe.uses
            : recipe.ingredients.map(\.foodKey)

        var stateByKey: [String: IngredientState] = [:]
        for key in neededKeys {
            if !fridgeKeys.contains(key) {
                stateByKey[key] = .toBuy
            } else if soonKeys.contains(key) {
                stateByKey[key] = .useSoon
            } else if lowKeys.contains(key) {
                stateByKey[key] = .low
            } else {
                stateByKey[key] = .have
            }
        }

        let haveCount = stateByKey.values.filter { $0 != .toBuy }.count
        let total = max(neededKeys.count, 1)
        let pct = Int((Double(haveCount) / Double(total) * 100).rounded())

        let missing = recipe.ingredients.filter { stateByKey[$0.foodKey] == .toBuy }
        let useSoon = recipe.ingredients.filter { stateByKey[$0.foodKey] == .useSoon }

        return RecipeMatch(
            recipe: recipe,
            matchPct: pct,
            missingIngredients: missing,
            useSoonIngredients: useSoon,
            stateByKey: stateByKey
        )
    }

    /// Sort recipes by how cook-able they are right now.
    /// 1. Higher matchPct first
    /// 2. Ties broken by "uses something expiring soon" (urgency)
    /// 3. Then by shorter cook time
    static func rank(recipes: [Recipe], fridge: [FoodItem]) -> [RecipeMatch] {
        let matches = recipes.map { match(recipe: $0, fridge: fridge) }
        return matches.sorted { a, b in
            if a.matchPct != b.matchPct { return a.matchPct > b.matchPct }
            if a.useSoonIngredients.count != b.useSoonIngredients.count {
                return a.useSoonIngredients.count > b.useSoonIngredients.count
            }
            return a.recipe.timeMinutes < b.recipe.timeMinutes
        }
    }
}

private extension RecipeIngredient {
    func with(have: Bool, useSoon: Bool, low: Bool) -> RecipeIngredient {
        var copy = self
        copy.have = have
        copy.useSoon = useSoon
        copy.low = low
        return copy
    }
}

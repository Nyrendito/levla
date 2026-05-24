import Foundation

/// One "Start cooking" event the user logged. We sum these per-day to
/// drive the macros bar on Home. Fiber/sugar/sodium are nullable so
/// older rows (logged before we tracked micros) still decode cleanly.
struct CookedEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var recipeSlug: String
    var recipeTitle: String
    var servings: Int
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var fiber: Int?       // grams
    var sugar: Int?       // grams
    var sodium: Int?      // milligrams
    var cookedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipeSlug = "recipe_slug"
        case recipeTitle = "recipe_title"
        case servings, kcal, protein, carbs, fat, fiber, sugar, sodium
        case cookedAt = "cooked_at"
    }

    init(id: UUID = UUID(),
         userId: UUID,
         recipeSlug: String,
         recipeTitle: String,
         servings: Int,
         kcal: Int,
         protein: Int,
         carbs: Int,
         fat: Int,
         fiber: Int? = nil,
         sugar: Int? = nil,
         sodium: Int? = nil,
         cookedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.recipeSlug = recipeSlug
        self.recipeTitle = recipeTitle
        self.servings = servings
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.cookedAt = cookedAt
    }
}

import Foundation

/// One "Start cooking" event the user logged. We sum these per-day to
/// drive the macros bar on Home.
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
    var cookedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipeSlug = "recipe_slug"
        case recipeTitle = "recipe_title"
        case servings, kcal, protein, carbs, fat
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
        self.cookedAt = cookedAt
    }
}

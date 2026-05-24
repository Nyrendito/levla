import Foundation
import SwiftUI

struct RecipeIngredient: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var foodKey: String
    var name: String
    var amount: String
    var have: Bool
    var useSoon: Bool
    var low: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case foodKey = "food_key"
        case name, amount, have
        case useSoon = "use_soon"
        case low
    }

    init(id: UUID = UUID(), foodKey: String, name: String, amount: String, have: Bool = true, useSoon: Bool = false, low: Bool = false) {
        self.id = id
        self.foodKey = foodKey
        self.name = name
        self.amount = amount
        self.have = have
        self.useSoon = useSoon
        self.low = low
    }
}

struct Recipe: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var slug: String
    var title: String
    var subtitle: String
    var timeMinutes: Int
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var difficulty: String
    var matchPct: Int
    var missing: [String]
    var uses: [String]
    var why: String
    var colorHex: String
    var accentHex: String
    var tags: [String]
    var ingredients: [RecipeIngredient]
    var steps: [String]

    enum CodingKeys: String, CodingKey {
        case id, slug, title, subtitle
        case timeMinutes = "time_minutes"
        case kcal, protein, carbs, fat, difficulty
        case matchPct = "match_pct"
        case missing, uses, why
        case colorHex = "color_hex"
        case accentHex = "accent_hex"
        case tags, ingredients, steps
    }

    var color: Color { Color(hex: UInt32(colorHex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xF3D6C6) }
    var accent: Color { Color(hex: UInt32(accentHex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xC9543C) }
}

struct ShoppingListItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var name: String
    var qty: String
    var section: String
    var auto: Bool
    var forRecipe: String?
    var checked: Bool
    var inFridge: Bool
    var addedBy: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name, qty, section, auto
        case forRecipe = "for_recipe"
        case checked
        case inFridge = "in_fridge"
        case addedBy = "added_by"
        case createdAt = "created_at"
    }
}

struct Profile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var displayName: String?
    var streakDays: Int
    var fridgeScore: Int

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case streakDays = "streak_days"
        case fridgeScore = "fridge_score"
    }
}

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

enum MealType: String, Codable, Hashable, Sendable, CaseIterable {
    case breakfast, lunch, dinner, snack

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .dinner:    return "Dinner"
        case .snack:     return "Snack"
        }
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
    var mealType: MealType
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
        case kcal, protein, carbs, fat
        case mealType = "meal_type"
        case difficulty
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

enum UserSex: String, Codable, Hashable, Sendable, CaseIterable {
    case male, female, other
    case preferNotToSay = "prefer_not_to_say"

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum UserGoal: String, Codable, Hashable, Sendable, CaseIterable {
    case loseFat = "lose_fat"
    case maintain
    case gainMuscle = "gain_muscle"
    case generalHealth = "general_health"

    var displayName: String {
        switch self {
        case .loseFat: return "Lose fat"
        case .maintain: return "Maintain weight"
        case .gainMuscle: return "Gain muscle"
        case .generalHealth: return "General health"
        }
    }

    var emoji: String {
        switch self {
        case .loseFat: return "🔥"
        case .maintain: return "⚖️"
        case .gainMuscle: return "💪"
        case .generalHealth: return "🌿"
        }
    }
}

enum ActivityLevel: String, Codable, Hashable, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case veryActive = "very_active"
    case athlete

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly active"
        case .moderate: return "Moderately active"
        case .veryActive: return "Very active"
        case .athlete: return "Athlete"
        }
    }

    var sublabel: String {
        switch self {
        case .sedentary: return "Mostly sitting, little exercise"
        case .light: return "Light exercise 1–3 days/week"
        case .moderate: return "Moderate exercise 3–5 days/week"
        case .veryActive: return "Hard exercise 6–7 days/week"
        case .athlete: return "Pro level, twice a day"
        }
    }

    /// Mifflin-St Jeor activity factor.
    var factor: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .veryActive: return 1.725
        case .athlete: return 1.9
        }
    }
}

struct Profile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var displayName: String?
    var streakDays: Int
    var fridgeScore: Int

    // Personalization fields — added when the user goes through onboarding.
    var sex: UserSex?
    var birthYear: Int?
    var heightCm: Int?
    var weightKg: Double?
    var goal: UserGoal?
    var activityLevel: ActivityLevel?
    var dietaryPrefs: [String]
    var onboarded: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case streakDays = "streak_days"
        case fridgeScore = "fridge_score"
        case sex
        case birthYear = "birth_year"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case goal
        case activityLevel = "activity_level"
        case dietaryPrefs = "dietary_prefs"
        case onboarded
    }

    init(
        id: UUID,
        displayName: String? = nil,
        streakDays: Int = 0,
        fridgeScore: Int = 0,
        sex: UserSex? = nil,
        birthYear: Int? = nil,
        heightCm: Int? = nil,
        weightKg: Double? = nil,
        goal: UserGoal? = nil,
        activityLevel: ActivityLevel? = nil,
        dietaryPrefs: [String] = [],
        onboarded: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.streakDays = streakDays
        self.fridgeScore = fridgeScore
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goal = goal
        self.activityLevel = activityLevel
        self.dietaryPrefs = dietaryPrefs
        self.onboarded = onboarded
    }

    /// Defensive decoder: profiles created before personalization columns
    /// existed don't have these keys, and Postgres serializes empty arrays
    /// inconsistently across clients. Default everything sensibly so the
    /// app boots even on a half-filled row.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self, forKey: .id)
        displayName   = try? c.decode(String.self, forKey: .displayName)
        streakDays    = (try? c.decode(Int.self, forKey: .streakDays))    ?? 0
        fridgeScore   = (try? c.decode(Int.self, forKey: .fridgeScore))   ?? 0
        sex           = try? c.decode(UserSex.self, forKey: .sex)
        birthYear     = try? c.decode(Int.self, forKey: .birthYear)
        heightCm      = try? c.decode(Int.self, forKey: .heightCm)
        weightKg      = try? c.decode(Double.self, forKey: .weightKg)
        goal          = try? c.decode(UserGoal.self, forKey: .goal)
        activityLevel = try? c.decode(ActivityLevel.self, forKey: .activityLevel)
        dietaryPrefs  = (try? c.decode([String].self, forKey: .dietaryPrefs)) ?? []
        onboarded     = (try? c.decode(Bool.self, forKey: .onboarded))    ?? false
    }

    /// Computed: rough age in years from birth year. Returns nil if missing.
    var age: Int? {
        guard let birthYear else { return nil }
        let nowYear = Calendar.current.component(.year, from: Date())
        let age = nowYear - birthYear
        return age >= 0 && age < 130 ? age : nil
    }

    /// Mifflin-St Jeor BMR (kcal/day). Returns nil if any field missing.
    var bmrKcal: Int? {
        guard let weightKg, let heightCm, let age, let sex else { return nil }
        let s: Double = sex == .male ? 5 : (sex == .female ? -161 : -78)
        let bmr = 10 * weightKg + 6.25 * Double(heightCm) - 5 * Double(age) + s
        return Int(bmr.rounded())
    }

    /// Daily calorie target — BMR × activity factor, adjusted by goal.
    var dailyKcalGoal: Int? {
        guard let bmrKcal, let activityLevel else { return nil }
        let tdee = Double(bmrKcal) * activityLevel.factor
        let adjusted: Double
        switch goal {
        case .loseFat?:      adjusted = tdee - 500
        case .gainMuscle?:   adjusted = tdee + 300
        case .maintain?, .generalHealth?, nil: adjusted = tdee
        }
        return Int(adjusted.rounded())
    }

    /// Protein target grams. 1.6g/kg for muscle gain / fat loss, 1.2g/kg
    /// for maintenance.
    var dailyProteinGoal: Int? {
        guard let weightKg else { return nil }
        let perKg: Double
        switch goal {
        case .gainMuscle?, .loseFat?: perKg = 1.6
        default:                      perKg = 1.2
        }
        return Int((weightKg * perKg).rounded())
    }

    /// 25% of kcal from fat, ÷9 kcal/g.
    var dailyFatGoal: Int? {
        guard let dailyKcalGoal else { return nil }
        return Int((Double(dailyKcalGoal) * 0.25 / 9).rounded())
    }

    /// Remaining kcal split between carbs at 4 kcal/g.
    var dailyCarbsGoal: Int? {
        guard let dailyKcalGoal, let dailyProteinGoal, let dailyFatGoal else { return nil }
        let remaining = Double(dailyKcalGoal) - Double(dailyProteinGoal * 4) - Double(dailyFatGoal * 9)
        return max(0, Int((remaining / 4).rounded()))
    }
}

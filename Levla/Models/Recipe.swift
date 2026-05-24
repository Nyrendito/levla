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

    // Baseline AI-generated plan. Stored at the end of onboarding via
    // `generate-meal-plan`. Subsequent weight / height tweaks adjust the
    // baseline locally using Mifflin-St Jeor deltas, so the plan stays
    // smart but small input changes still nudge the targets.
    var baselineKcalGoal: Int?
    var baselineProteinGoal: Int?
    var baselineCarbsGoal: Int?
    var baselineFatGoal: Int?
    var baselineFiberGoal: Int?
    var baselineSugarGoal: Int?
    var baselineSodiumGoal: Int?
    var baselineWeightKg: Double?
    var baselineHeightCm: Int?
    var baselineAge: Int?
    var baselineSex: UserSex?
    var baselineActivity: ActivityLevel?
    var baselineGoal: UserGoal?
    var planRationale: String?
    var planGeneratedAt: Date?

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
        case baselineKcalGoal    = "baseline_kcal_goal"
        case baselineProteinGoal = "baseline_protein_goal"
        case baselineCarbsGoal   = "baseline_carbs_goal"
        case baselineFatGoal     = "baseline_fat_goal"
        case baselineFiberGoal   = "baseline_fiber_goal"
        case baselineSugarGoal   = "baseline_sugar_goal"
        case baselineSodiumGoal  = "baseline_sodium_goal"
        case baselineWeightKg    = "baseline_weight_kg"
        case baselineHeightCm    = "baseline_height_cm"
        case baselineAge         = "baseline_age"
        case baselineSex         = "baseline_sex"
        case baselineActivity    = "baseline_activity"
        case baselineGoal        = "baseline_goal"
        case planRationale       = "plan_rationale"
        case planGeneratedAt     = "plan_generated_at"
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
        onboarded: Bool = false,
        baselineKcalGoal: Int? = nil,
        baselineProteinGoal: Int? = nil,
        baselineCarbsGoal: Int? = nil,
        baselineFatGoal: Int? = nil,
        baselineFiberGoal: Int? = nil,
        baselineSugarGoal: Int? = nil,
        baselineSodiumGoal: Int? = nil,
        baselineWeightKg: Double? = nil,
        baselineHeightCm: Int? = nil,
        baselineAge: Int? = nil,
        baselineSex: UserSex? = nil,
        baselineActivity: ActivityLevel? = nil,
        baselineGoal: UserGoal? = nil,
        planRationale: String? = nil,
        planGeneratedAt: Date? = nil
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
        self.baselineKcalGoal = baselineKcalGoal
        self.baselineProteinGoal = baselineProteinGoal
        self.baselineCarbsGoal = baselineCarbsGoal
        self.baselineFatGoal = baselineFatGoal
        self.baselineFiberGoal = baselineFiberGoal
        self.baselineSugarGoal = baselineSugarGoal
        self.baselineSodiumGoal = baselineSodiumGoal
        self.baselineWeightKg = baselineWeightKg
        self.baselineHeightCm = baselineHeightCm
        self.baselineAge = baselineAge
        self.baselineSex = baselineSex
        self.baselineActivity = baselineActivity
        self.baselineGoal = baselineGoal
        self.planRationale = planRationale
        self.planGeneratedAt = planGeneratedAt
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

        baselineKcalGoal    = try? c.decode(Int.self,           forKey: .baselineKcalGoal)
        baselineProteinGoal = try? c.decode(Int.self,           forKey: .baselineProteinGoal)
        baselineCarbsGoal   = try? c.decode(Int.self,           forKey: .baselineCarbsGoal)
        baselineFatGoal     = try? c.decode(Int.self,           forKey: .baselineFatGoal)
        baselineFiberGoal   = try? c.decode(Int.self,           forKey: .baselineFiberGoal)
        baselineSugarGoal   = try? c.decode(Int.self,           forKey: .baselineSugarGoal)
        baselineSodiumGoal  = try? c.decode(Int.self,           forKey: .baselineSodiumGoal)
        baselineWeightKg    = try? c.decode(Double.self,        forKey: .baselineWeightKg)
        baselineHeightCm    = try? c.decode(Int.self,           forKey: .baselineHeightCm)
        baselineAge         = try? c.decode(Int.self,           forKey: .baselineAge)
        baselineSex         = try? c.decode(UserSex.self,       forKey: .baselineSex)
        baselineActivity    = try? c.decode(ActivityLevel.self, forKey: .baselineActivity)
        baselineGoal        = try? c.decode(UserGoal.self,      forKey: .baselineGoal)
        planRationale       = try? c.decode(String.self,        forKey: .planRationale)
        planGeneratedAt     = try? c.decode(Date.self,          forKey: .planGeneratedAt)
    }

    /// Computed: rough age in years from birth year. Returns nil if missing.
    var age: Int? {
        guard let birthYear else { return nil }
        let nowYear = Calendar.current.component(.year, from: Date())
        let age = nowYear - birthYear
        return age >= 0 && age < 130 ? age : nil
    }

    /// Mifflin-St Jeor BMR for the user's CURRENT stats (kcal/day).
    /// Returns nil if any field missing.
    var bmrKcal: Int? {
        guard let weightKg, let heightCm, let age, let sex else { return nil }
        return Self.bmr(weightKg: weightKg, heightCm: heightCm, age: age, sex: sex)
    }

    /// Mifflin-St Jeor BMR with explicit inputs (used for baseline-vs-current
    /// delta math). Returns nil if any required input is missing.
    static func bmr(weightKg: Double?, heightCm: Int?, age: Int?, sex: UserSex?) -> Int? {
        guard let weightKg, let heightCm, let age, let sex else { return nil }
        let s: Double = sex == .male ? 5 : (sex == .female ? -161 : -78)
        let bmr = 10 * weightKg + 6.25 * Double(heightCm) - 5 * Double(age) + s
        return Int(bmr.rounded())
    }

    // MARK: - Daily goals (baseline plan + smart delta, falling back to Mifflin)

    /// Daily calorie target. Prefers the AI-generated baseline + a Mifflin-
    /// St Jeor delta for changes in weight / height / age / activity since
    /// the plan was generated. If no baseline exists, falls back to a pure
    /// Mifflin calculation.
    ///
    /// The delta keeps the personalized plan stable while still nudging the
    /// numbers when the user updates their stats. Drop 10 kg → BMR roughly
    /// drops by 100 kcal, TDEE drops ~150-190 kcal depending on activity.
    var dailyKcalGoal: Int? {
        if let baselineKcal = baselineKcalGoal {
            return baselineKcal + kcalDelta()
        }
        return computedKcalGoal()
    }

    /// Pure-Mifflin kcal goal, used when no AI baseline is available.
    private func computedKcalGoal() -> Int? {
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

    /// kcal delta to apply to the baseline kcal goal based on how the user's
    /// current stats differ from the baseline snapshot. Computed at the
    /// TDEE level (BMR × activity factor) so weight, height, age, and
    /// activity-level changes all flow through proportionally.
    private func kcalDelta() -> Int {
        guard let currentBMR = bmrKcal,
              let currentAct = activityLevel,
              let baselineBMR = Profile.bmr(
                weightKg: baselineWeightKg,
                heightCm: baselineHeightCm,
                age: baselineAge,
                sex: baselineSex
              ),
              let baselineAct = baselineActivity
        else { return 0 }
        let currentTDEE  = Double(currentBMR)  * currentAct.factor
        let baselineTDEE = Double(baselineBMR) * baselineAct.factor
        return Int((currentTDEE - baselineTDEE).rounded())
    }

    /// Protein target. Scales the baseline value by the ratio of current to
    /// baseline body weight (1.6 g/kg behaviour, just expressed as a ratio).
    /// Falls back to the pure 1.2/1.6 g/kg rule when no baseline exists.
    var dailyProteinGoal: Int? {
        if let baseProtein = baselineProteinGoal,
           let baseWeight = baselineWeightKg, baseWeight > 0,
           let weightKg, weightKg > 0 {
            return Int((Double(baseProtein) * (weightKg / baseWeight)).rounded())
        }
        guard let weightKg else { return baselineProteinGoal }
        let perKg: Double
        switch goal {
        case .gainMuscle?, .loseFat?: perKg = 1.6
        default:                      perKg = 1.2
        }
        return Int((weightKg * perKg).rounded())
    }

    /// Fat target. If we have a baseline, scale by the kcal ratio so the
    /// 25-35%-of-energy distribution holds as the kcal goal moves.
    var dailyFatGoal: Int? {
        if let baseFat = baselineFatGoal,
           let baseKcal = baselineKcalGoal, baseKcal > 0,
           let currentKcal = dailyKcalGoal {
            return Int((Double(baseFat) * Double(currentKcal) / Double(baseKcal)).rounded())
        }
        guard let dailyKcalGoal else { return baselineFatGoal }
        return Int((Double(dailyKcalGoal) * 0.25 / 9).rounded())
    }

    /// Carbs = remaining kcal after protein + fat, ÷ 4 kcal/g.
    var dailyCarbsGoal: Int? {
        guard let dailyKcalGoal, let dailyProteinGoal, let dailyFatGoal else { return baselineCarbsGoal }
        let remaining = Double(dailyKcalGoal) - Double(dailyProteinGoal * 4) - Double(dailyFatGoal * 9)
        return max(0, Int((remaining / 4).rounded()))
    }

    // MARK: - Micros — baseline preferred, fallbacks via reference intakes

    /// Daily fiber. AI baseline first, otherwise IOM 14 g per 1,000 kcal.
    var dailyFiberGoal: Int? {
        if let b = baselineFiberGoal { return b }
        if let kcal = dailyKcalGoal {
            return Int((Double(kcal) * 14.0 / 1000.0).rounded())
        }
        switch sex {
        case .male?:   return 38
        case .female?: return 25
        default:       return 30
        }
    }

    /// Daily added-sugar ceiling. AI baseline first, otherwise WHO < 10%.
    var dailySugarGoal: Int? {
        if let b = baselineSugarGoal { return b }
        guard let kcal = dailyKcalGoal else { return 50 }
        return Int((Double(kcal) * 0.10 / 4.0).rounded())
    }

    /// Daily sodium ceiling. AI baseline first, otherwise AHA 2,300 mg.
    var dailySodiumGoal: Int? { baselineSodiumGoal ?? 2_300 }

    // MARK: - Plan freshness

    /// True when any of the stats that drove the baseline plan differ
    /// meaningfully from current state. Used as a hint to nudge the user
    /// to regenerate the plan from their profile settings.
    var planNeedsRefresh: Bool {
        guard baselineKcalGoal != nil else { return false }   // never had a plan; not stale
        if let bw = baselineWeightKg, let cw = weightKg, abs(bw - cw) >= 5 { return true }
        if baselineGoal != goal { return true }
        if baselineActivity != activityLevel { return true }
        return false
    }
}

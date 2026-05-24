import Foundation

/// Status mapped from `days_left` per the design's freshness model.
enum FreshnessStatus: String, Codable, CaseIterable, Sendable {
    case today, soon, fresh, low
}

enum FoodCategory: String, Codable, CaseIterable, Sendable {
    case dairy = "Dairy"
    case vegetables = "Vegetables"
    case meat = "Meat"
    case pantry = "Pantry"
    case drinks = "Drinks"
    case freezer = "Freezer"
}

enum AIConfidence: String, Codable, Sendable {
    case high, med
}

/// A food item in the user's fridge.
/// `food_key` is the illustration key (e.g. "salmon"); `name` is the display name.
struct FoodItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var name: String
    var foodKey: String
    var category: FoodCategory
    var qty: String
    var daysLeft: Int
    var confidence: AIConfidence
    var addedAt: Date
    var source: AddSource
    var isLow: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case foodKey = "food_key"
        case category
        case qty
        case daysLeft = "days_left"
        case confidence
        case addedAt = "added_at"
        case source
        case isLow = "is_low"
    }

    /// Only two statuses surface in the UI: low (running out) or fresh
    /// (everything else). We deliberately don't expose time-based "expires
    /// in N days" buckets because we can't reliably infer them from a single
    /// fridge photo — best not to lie to the user.
    var status: FreshnessStatus {
        isLow ? .low : .fresh
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        foodKey: String,
        category: FoodCategory,
        qty: String,
        daysLeft: Int,
        confidence: AIConfidence = .high,
        addedAt: Date = Date(),
        source: AddSource = .manual,
        isLow: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.foodKey = foodKey
        self.category = category
        self.qty = qty
        self.daysLeft = daysLeft
        self.confidence = confidence
        self.addedAt = addedAt
        self.source = source
        self.isLow = isLow
    }
}

enum AddSource: String, Codable, Sendable {
    case scan, receipt, voice, manual
}

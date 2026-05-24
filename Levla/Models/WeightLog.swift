import Foundation

/// One weigh-in. We keep history (rather than just storing the latest weight
/// on profiles) so the Progress tab can render a Goal Progress line chart
/// over weeks/months.
struct WeightLog: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var userId: UUID
    var weightKg: Double
    var loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case weightKg = "weight_kg"
        case loggedAt = "logged_at"
    }

    init(id: UUID = UUID(), userId: UUID, weightKg: Double, loggedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.weightKg = weightKg
        self.loggedAt = loggedAt
    }
}

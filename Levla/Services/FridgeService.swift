import Foundation
import Supabase

/// Backend service for the user's fridge inventory. Falls back to an
/// in-memory store when Supabase credentials are missing.
@MainActor
@Observable
final class FridgeService {
    private(set) var items: [FoodItem] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let supabase = LevlaSupabase.shared
    private var offlineStore: [FoodItem] = []

    // MARK: - Derived

    var todayCount: Int { items.filter { $0.status == .today }.count }
    var soonCount:  Int { items.filter { $0.status == .soon }.count }
    var freshCount: Int { items.filter { $0.status == .fresh }.count }
    var lowCount:   Int { items.filter { $0.status == .low }.count }
    var total:      Int { items.count }

    var freshPct: Double { total == 0 ? 0 : Double(freshCount) / Double(total) }

    /// 0–10 score that responds to fridge state. Driven entirely by what's
    /// currently in `items` — no DB column needed.
    var fridgeScore: Int {
        guard total > 0 else { return 5 }
        // Cost 2 per expiring-today item; 1 per expiring-soon; 0.5 per low.
        let penalty = Double(todayCount) * 2.0 + Double(soonCount) * 1.0 + Double(lowCount) * 0.5
        let raw = 10.0 - min(10.0, penalty)
        return max(0, min(10, Int(raw.rounded())))
    }

    /// Number of distinct calendar days the user has added items on.
    /// Approximates "you've been active this many days" — caps at 99.
    var streakDays: Int {
        let cal = Calendar.current
        let days = Set(items.map { cal.startOfDay(for: $0.addedAt) })
        return min(99, days.count)
    }

    func reload(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        if supabase.isOffline {
            if offlineStore.isEmpty {
                offlineStore = SeedData.demoInventory(userId: userId)
            }
            items = offlineStore
            return
        }

        guard let client = supabase.client else { return }
        do {
            let rows: [FoodItem] = try await client
                .from("food_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("added_at", ascending: false)
                .execute()
                .value
            items = rows
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(_ items: [FoodItem]) async {
        if supabase.isOffline {
            offlineStore.insert(contentsOf: items, at: 0)
            self.items = offlineStore
            return
        }
        guard let client = supabase.client else { return }
        do {
            try await client.from("food_items").insert(items).execute()
            if let userId = items.first?.userId {
                await reload(userId: userId)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(_ item: FoodItem) async { await add([item]) }

    func remove(_ item: FoodItem) async {
        if supabase.isOffline {
            offlineStore.removeAll { $0.id == item.id }
            items = offlineStore
            return
        }
        guard let client = supabase.client else { return }
        try? await client.from("food_items").delete().eq("id", value: item.id.uuidString).execute()
        await reload(userId: item.userId)
    }

    func update(_ item: FoodItem) async {
        if supabase.isOffline {
            offlineStore = offlineStore.map { $0.id == item.id ? item : $0 }
            items = offlineStore
            return
        }
        guard let client = supabase.client else { return }
        try? await client.from("food_items").update(item).eq("id", value: item.id.uuidString).execute()
        await reload(userId: item.userId)
    }
}

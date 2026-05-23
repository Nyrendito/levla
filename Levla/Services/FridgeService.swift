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

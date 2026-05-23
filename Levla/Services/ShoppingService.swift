import Foundation
import Supabase

@MainActor
@Observable
final class ShoppingService {
    private(set) var items: [ShoppingListItem] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let supabase = LevlaSupabase.shared
    private var offlineStore: [ShoppingListItem] = []

    var sections: [String] {
        Array(Set(items.map(\.section))).sorted()
    }

    func grouped() -> [(section: String, items: [ShoppingListItem])] {
        let dict = Dictionary(grouping: items, by: \.section)
        let order = ["Produce", "Dairy", "Pantry", "Bakery", "Other"]
        return order.compactMap { sec in
            guard let arr = dict[sec], !arr.isEmpty else { return nil }
            return (sec, arr.sorted { $0.createdAt < $1.createdAt })
        } + dict
            .filter { !order.contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    func reload(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        if supabase.isOffline {
            if offlineStore.isEmpty {
                offlineStore = SeedData.demoShopping(userId: userId)
            }
            items = offlineStore
            return
        }
        guard let client = supabase.client else { return }
        do {
            let rows: [ShoppingListItem] = try await client
                .from("shopping_items")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            items = rows
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(_ item: ShoppingListItem) async {
        if supabase.isOffline {
            offlineStore.append(item)
            items = offlineStore
            return
        }
        guard let client = supabase.client else { return }
        try? await client.from("shopping_items").insert(item).execute()
        await reload(userId: item.userId)
    }

    func toggle(_ id: UUID) async {
        if supabase.isOffline {
            if let i = offlineStore.firstIndex(where: { $0.id == id }) {
                offlineStore[i].checked.toggle()
                items = offlineStore
            }
            return
        }
        guard let client = supabase.client, let item = items.first(where: { $0.id == id }) else { return }
        var updated = item
        updated.checked.toggle()
        try? await client.from("shopping_items").update(updated).eq("id", value: id.uuidString).execute()
        await reload(userId: item.userId)
    }

    func remove(_ id: UUID) async {
        if supabase.isOffline {
            offlineStore.removeAll { $0.id == id }
            items = offlineStore
            return
        }
        guard let client = supabase.client, let userId = items.first(where: { $0.id == id })?.userId else { return }
        try? await client.from("shopping_items").delete().eq("id", value: id.uuidString).execute()
        await reload(userId: userId)
    }
}

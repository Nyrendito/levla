import SwiftUI

/// Fridge — pure inventory. One sentence: "Here is what you have."
/// No dashboard, no status tiles, no category grid.
///
/// Layout:
/// 1. Header
/// 2. Search
/// 3. Scan fridge button
/// 4. "Use first" — urgent items, urgency-sorted
/// 5. "All items" — every item, grouped by category
struct FridgeView: View {
    @Environment(AppState.self) private var app
    @State private var search = ""

    private var allFiltered: [FoodItem] {
        if search.isEmpty { return app.fridge.items }
        let needle = search.lowercased()
        return app.fridge.items.filter { $0.name.lowercased().contains(needle) }
    }

    private var useFirst: [FoodItem] {
        allFiltered
            .filter { $0.status == .today || $0.status == .soon || $0.status == .low }
            .sorted(by: byUrgency)
    }

    private var groupedByCategory: [(FoodCategory, [FoodItem])] {
        let dict = Dictionary(grouping: allFiltered, by: \.category)
        return FoodCategory.allCases.compactMap { cat in
            guard let arr = dict[cat], !arr.isEmpty else { return nil }
            return (cat, arr.sorted(by: byUrgency))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header.padding(.horizontal, L.S.pad).padding(.top, 60)
                searchField.padding(.horizontal, L.S.pad).padding(.top, 18)
                BigCTA(title: "Scan fridge", icon: "camera", kind: .primary) {
                    app.presentingScan = .fridge
                }
                .padding(.horizontal, L.S.pad)
                .padding(.top, 14)

                if !useFirst.isEmpty {
                    useFirstSection.padding(.top, 26)
                }

                allItemsSection.padding(.top, 26)

                Color.clear.frame(height: 130)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .task {
            if let uid = app.auth.currentUserId, app.fridge.items.isEmpty {
                await app.fridge.reload(userId: uid)
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            Text("My fridge")
                .font(.manrope(34, .heavy))
                .kerning(-1.1)
                .foregroundStyle(L.ink)
            Spacer()
            if app.fridge.total > 0 {
                Text("\(app.fridge.total)")
                    .font(.manrope(15, .heavy))
                    .foregroundStyle(L.ink.opacity(0.4))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            LSymbol(key: "search", size: 18, weight: .semibold).foregroundStyle(L.ink.opacity(0.45))
            TextField("", text: $search, prompt: Text("Search your fridge").foregroundStyle(L.ink.opacity(0.4)))
                .font(.manrope(16, .semibold))
                .foregroundStyle(L.ink)
                .autocorrectionDisabled()
            if !search.isEmpty {
                Button { search = "" } label: {
                    LSymbol(key: "close", size: 14, weight: .heavy)
                        .foregroundStyle(L.ink.opacity(0.45))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .modifier(_FridgeSoft())
    }

    @ViewBuilder
    private var useFirstSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("USE FIRST")
                    .font(.mono(11)).tracking(1.2)
                    .foregroundStyle(L.ink.opacity(0.4))
                Spacer()
                Text("\(useFirst.count)")
                    .font(.manrope(12, .heavy))
                    .foregroundStyle(L.ink.opacity(0.4))
            }
            .padding(.horizontal, L.S.pad)

            VStack(spacing: 8) {
                ForEach(useFirst) { item in
                    BigFoodPill(
                        food: item.foodKey, name: item.name, qty: item.qty,
                        status: item.status, days: item.daysLeft
                    )
                }
            }
            .padding(.horizontal, L.S.pad)
        }
    }

    @ViewBuilder
    private var allItemsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("ALL ITEMS")
                    .font(.mono(11)).tracking(1.2)
                    .foregroundStyle(L.ink.opacity(0.4))
                Spacer()
                Text("\(allFiltered.count)")
                    .font(.manrope(12, .heavy))
                    .foregroundStyle(L.ink.opacity(0.4))
            }
            .padding(.horizontal, L.S.pad)

            if groupedByCategory.isEmpty {
                emptyState
            } else {
                ForEach(groupedByCategory, id: \.0) { (cat, items) in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(cat.rawValue)
                            .font(.manrope(18, .heavy))
                            .kerning(-0.4)
                            .foregroundStyle(L.ink)
                            .padding(.horizontal, L.S.pad)
                        VStack(spacing: 8) {
                            ForEach(items) { item in
                                BigFoodPill(
                                    food: item.foodKey, name: item.name, qty: item.qty,
                                    status: item.status, days: item.daysLeft
                                )
                            }
                        }
                        .padding(.horizontal, L.S.pad)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(search.isEmpty ? "Nothing in your fridge yet." : "No matches.")
                .font(.manrope(16, .heavy))
                .foregroundStyle(L.ink)
            Text(search.isEmpty ? "Scan it in to get started." : "Try a different search.")
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(_FridgeCardShadow())
        .padding(.horizontal, L.S.pad)
    }

    private func byUrgency(_ a: FoodItem, _ b: FoodItem) -> Bool {
        let order: [FreshnessStatus: Int] = [.today: 0, .soon: 1, .low: 2, .fresh: 3]
        let ao = order[a.status] ?? 4
        let bo = order[b.status] ?? 4
        if ao != bo { return ao < bo }
        return a.daysLeft < b.daysLeft
    }
}

private struct _FridgeSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}
private struct _FridgeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

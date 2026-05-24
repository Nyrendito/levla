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

    private var groupedByCategory: [(FoodCategory, [FoodItem])] {
        let dict = Dictionary(grouping: allFiltered, by: \.category)
        return FoodCategory.allCases.compactMap { cat in
            guard let arr = dict[cat], !arr.isEmpty else { return nil }
            return (cat, arr.sorted { $0.name < $1.name })
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
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Your inventory")
            HStack(alignment: .lastTextBaseline) {
                Text("My fridge")
                    .font(.manrope(28, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Spacer()
                if app.fridge.total > 0 {
                    Text("\(app.fridge.total) items")
                        .font(.manrope(13, .heavy))
                        .tracking(0.4)
                        .foregroundStyle(L.muted)
                }
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
    private var allItemsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                SectionLabel(text: "All items")
                Spacer()
                Text("\(allFiltered.count)")
                    .font(.manrope(11, .heavy))
                    .tracking(1.4)
                    .foregroundStyle(L.muted)
            }
            .padding(.horizontal, L.S.pad)

            if groupedByCategory.isEmpty {
                emptyState
            } else {
                ForEach(groupedByCategory, id: \.0) { (cat, items) in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(cat.rawValue)
                            .font(.manrope(16, .heavy))
                            .kerning(-0.3)
                            .foregroundStyle(L.ink)
                            .padding(.horizontal, L.S.pad)
                        VStack(spacing: 8) {
                            ForEach(items) { item in
                                BigFoodPill(
                                    food: item.foodKey, name: item.name, qty: item.qty,
                                    status: item.status
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

}

private struct _FridgeSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}
private struct _FridgeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

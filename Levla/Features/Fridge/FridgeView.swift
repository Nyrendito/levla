import SwiftUI

/// Fridge — status strip, category tiles, item pills. Mirrors V2Fridge.
struct FridgeView: View {
    @Environment(AppState.self) private var app

    @State private var selectedCategory: String = "All"
    @State private var search = ""
    @State private var showingSearch = false

    private var filtered: [FoodItem] {
        let base = selectedCategory == "All"
            ? app.fridge.items
            : app.fridge.items.filter { $0.category.rawValue == selectedCategory }
        if search.isEmpty { return base.sorted(by: byUrgency) }
        let needle = search.lowercased()
        return base.filter { $0.name.lowercased().contains(needle) }.sorted(by: byUrgency)
    }

    private var useFirst: [FoodItem] {
        app.fridge.items
            .filter { $0.status == .today || $0.status == .soon }
            .sorted(by: byUrgency)
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BigHeader(title: "My fridge", sub: "\(app.fridge.total) items") {
                    BigIconBtn(icon: "search") { withAnimation { showingSearch.toggle() } }
                }
                .padding(.horizontal, L.S.pad)

                if showingSearch {
                    searchField
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                statusStrip
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 18)

                BigCTA(title: "Scan my fridge", icon: "camera", kind: .pop) {
                    app.presentingScan = .fridge
                }
                .padding(.horizontal, L.S.pad)
                .padding(.top, 18)
                .padding(.bottom, 22)

                if !useFirst.isEmpty {
                    section("Use first") {
                        VStack(spacing: 8) {
                            ForEach(useFirst) { item in
                                BigFoodPill(food: item.foodKey, name: item.name, qty: item.qty, status: item.status, days: item.daysLeft)
                            }
                        }
                    }
                    .padding(.bottom, 22)
                }

                categorySection.padding(.bottom, 22)

                allItemsSection.padding(.bottom, 30)

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

    private var searchField: some View {
        HStack(spacing: 10) {
            LSymbol(key: "search", size: 18, weight: .semibold).foregroundStyle(L.ink.opacity(0.5))
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

    private var statusStrip: some View {
        HStack(spacing: 8) {
            StatusTile(count: app.fridge.todayCount, label: "Today", tone: .today)
            StatusTile(count: app.fridge.soonCount, label: "Soon", tone: .soon)
            StatusTile(count: app.fridge.freshCount, label: "Fresh", tone: .fresh)
            StatusTile(count: app.fridge.lowCount, label: "Low", tone: .low)
        }
    }

    private var categorySection: some View {
        section("Categories", action: AnyView(
            Text("\(filtered.count) items")
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.ink.opacity(0.5))
        )) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                CategoryTile(name: "All", count: app.fridge.total, active: selectedCategory == "All", bg: L.cream, food: "egg") {
                    selectedCategory = "All"
                }
                ForEach(FoodCategory.allCases.filter { $0 != .freezer }, id: \.self) { cat in
                    let count = app.fridge.items.filter { $0.category == cat }.count
                    if count > 0 {
                        let head = app.fridge.items.first { $0.category == cat }?.foodKey ?? "egg"
                        CategoryTile(
                            name: cat.rawValue,
                            count: count,
                            active: selectedCategory == cat.rawValue,
                            bg: bgForCategory(cat),
                            food: head
                        ) {
                            selectedCategory = cat.rawValue
                        }
                    }
                }
            }
        }
    }

    private var allItemsSection: some View {
        section(selectedCategory == "All" ? "Everything" : selectedCategory) {
            VStack(spacing: 8) {
                ForEach(filtered) { item in
                    BigFoodPill(food: item.foodKey, name: item.name, qty: item.qty, status: item.status, days: item.daysLeft)
                }
                if filtered.isEmpty {
                    Text(search.isEmpty ? "Nothing here yet." : "No matches.")
                        .font(.manrope(14, .semibold))
                        .foregroundStyle(L.ink.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }
        }
    }

    @ViewBuilder
    private func section<C: View>(_ title: String, action: AnyView? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text(title)
                    .font(.manrope(22, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.ink)
                Spacer()
                action
            }
            content()
        }
        .padding(.horizontal, L.S.pad)
    }

    private func bgForCategory(_ cat: FoodCategory) -> Color {
        switch cat {
        case .dairy: return Color(hex: 0xF0E9D6)
        case .vegetables: return L.mintBg
        case .meat: return L.popBg
        case .pantry: return Color(hex: 0xF4EBD5)
        case .drinks: return Color(hex: 0xE4EAEC)
        case .freezer: return L.cream
        }
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

/// Category tile — bigger pillar with food preview + count, dark when active.
struct CategoryTile: View {
    let name: String
    let count: Int
    let active: Bool
    let bg: Color
    let food: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(active ? L.cream.opacity(0.12) : bg)
                    FoodTile(food: food, size: 38, radius: 12)
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.manrope(15, .heavy))
                        .kerning(-0.3)
                        .lineLimit(1)
                    Text("\(count) item\(count == 1 ? "" : "s")")
                        .font(.manrope(12, .semibold))
                        .foregroundStyle((active ? L.cream : L.ink).opacity(active ? 0.6 : 0.55))
                }

                Spacer()
            }
            .padding(14)
            .foregroundStyle(active ? L.cream : L.ink)
            .background(active ? L.ink : Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_FridgeCardShadow(active: active))
        .tapPress()
    }
}

private struct _FridgeCardShadow: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        active ? AnyView(content.shadow(color: L.ink.opacity(0.18), radius: 16, x: 0, y: 8))
               : AnyView(L.Shadow.card(content))
    }
}

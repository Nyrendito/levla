import SwiftUI

/// Shopping — one sentence: "Buy what you're missing or running low on."
/// Supports the fridge → cook loop. NOT a standalone grocery app.
///
/// Three sections, purpose-grouped:
/// 1. For tonight — auto-added missing ingredients from recipes
/// 2. Running low — low-stock items from your fridge
/// 3. Added by you — manual entries
struct ShoppingView: View {
    @Environment(AppState.self) private var app
    @State private var newItemName = ""
    @State private var addingItem = false

    // MARK: - Derived groups

    private var forTonightItems: [ShoppingListItem] {
        app.shopping.items.filter { $0.auto && ($0.forRecipe ?? "").lowercased() != "running low" }
    }
    private var runningLowFromShopping: [ShoppingListItem] {
        app.shopping.items.filter { ($0.forRecipe ?? "").lowercased() == "running low" }
    }
    /// Items in fridge marked .low — surfaced even if no shopping_items row exists.
    private var runningLowFromFridge: [FoodItem] {
        app.fridge.items.filter { $0.status == .low }
    }
    private var addedByYouItems: [ShoppingListItem] {
        app.shopping.items.filter { !$0.auto }
    }

    private var totalUnchecked: Int {
        app.shopping.items.filter { !$0.checked }.count + runningLowFromFridge.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header.padding(.horizontal, L.S.pad).padding(.top, 60)

                if app.shopping.items.isEmpty && runningLowFromFridge.isEmpty {
                    emptyState.padding(.top, 28)
                } else {
                    if !forTonightItems.isEmpty {
                        section(title: "For tonight", items: forTonightItems, fridgeLows: []).padding(.top, 26)
                    }
                    if !runningLowFromShopping.isEmpty || !runningLowFromFridge.isEmpty {
                        section(title: "Running low", items: runningLowFromShopping, fridgeLows: runningLowFromFridge).padding(.top, 26)
                    }
                    if !addedByYouItems.isEmpty {
                        section(title: "Added by you", items: addedByYouItems, fridgeLows: []).padding(.top, 26)
                    }
                }

                addItemBar.padding(.horizontal, L.S.pad).padding(.top, 22)

                Color.clear.frame(height: 140)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .task {
            if let uid = app.auth.currentUserId, app.shopping.items.isEmpty {
                await app.shopping.reload(userId: uid)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Shopping list")
            HStack(alignment: .lastTextBaseline) {
                Text("Shopping")
                    .font(.manrope(28, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Spacer()
                if totalUnchecked > 0 {
                    Text("\(totalUnchecked) TO GRAB")
                        .font(.manrope(11, .heavy))
                        .tracking(1.4)
                        .foregroundStyle(L.muted)
                }
            }
        }
    }

    // MARK: - Section

    @ViewBuilder
    private func section(title: String, items: [ShoppingListItem], fridgeLows: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: title)
                Spacer()
                Text("\(items.count + fridgeLows.count)")
                    .font(.manrope(11, .heavy))
                    .tracking(1.4)
                    .foregroundStyle(L.muted)
            }
            .padding(.horizontal, L.S.pad)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { (i, item) in
                    BigShopRow(item: item, isLast: i == items.count - 1 && fridgeLows.isEmpty) {
                        Task { await app.shopping.toggle(item.id) }
                    }
                }
                ForEach(Array(fridgeLows.enumerated()), id: \.element.id) { (i, item) in
                    LowFromFridgeRow(item: item, isLast: i == fridgeLows.count - 1) {
                        promoteLowToShopping(item)
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )
            .padding(.horizontal, L.S.pad)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Nothing on your list.")
                .font(.manrope(18, .heavy))
                .foregroundStyle(L.ink)
            Text("As you cook, missing ingredients land here automatically.")
                .font(.manrope(13, .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(L.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .modifier(_ShoppingShadow())
        .padding(.horizontal, L.S.pad)
    }

    // MARK: - Add bar

    private var addItemBar: some View {
        VStack(spacing: 10) {
            if addingItem {
                HStack(spacing: 10) {
                    TextField("", text: $newItemName, prompt: Text("New item").foregroundStyle(L.ink.opacity(0.4)))
                        .font(.manrope(15, .semibold))
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .modifier(_ShoppingSoft())
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button("Add") { addItem() }
                        .font(.manrope(15, .heavy))
                        .padding(.horizontal, 18).frame(height: 50)
                        .background(L.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(L.cream)
                        .buttonStyle(.plain)
                }
            }
            BigCTA(title: addingItem ? "Cancel" : "Add item", icon: "plus", kind: .primary, subtle: true) {
                if addingItem, !newItemName.isEmpty {
                    addItem()
                } else {
                    withAnimation { addingItem.toggle() }
                }
            }
        }
    }

    // MARK: - Actions

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let userId = app.auth.currentUserId else { return }
        let item = ShoppingListItem(
            id: UUID(), userId: userId,
            name: trimmed, qty: "1", section: "Other",
            auto: false, forRecipe: nil, checked: false, inFridge: false, addedBy: nil, createdAt: Date()
        )
        Task { await app.shopping.add(item) }
        newItemName = ""
        withAnimation { addingItem = false }
    }

    private func promoteLowToShopping(_ item: FoodItem) {
        guard let userId = app.auth.currentUserId else { return }
        // Avoid duplicates
        if app.shopping.items.contains(where: { $0.name.lowercased() == item.name.lowercased() }) {
            return
        }
        let s = ShoppingListItem(
            id: UUID(), userId: userId,
            name: item.name, qty: item.qty, section: "Other",
            auto: true, forRecipe: "Running low", checked: false, inFridge: false, addedBy: nil, createdAt: Date()
        )
        Task { await app.shopping.add(s) }
    }
}

// MARK: - Row variants

struct BigShopRow: View {
    let item: ShoppingListItem
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(item.checked ? Color.clear : L.muted, lineWidth: 1.5)
                        if item.checked {
                            Circle().fill(L.brand)
                            LSymbol(key: "check", size: 14, weight: .heavy).foregroundStyle(.white)
                        }
                    }
                    .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.manrope(15, .heavy))
                            .kerning(-0.2)
                            .foregroundStyle(item.checked ? L.muted : L.ink)
                            .strikethrough(item.checked, color: L.muted)
                        HStack(spacing: 8) {
                            Text(item.qty)
                            if let r = item.forRecipe, r.lowercased() != "running low" {
                                Text("·").foregroundStyle(L.muted.opacity(0.5))
                                Text(r)
                            }
                        }
                        .font(.manrope(12, .semibold))
                        .foregroundStyle(L.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            if !isLast { Hairline(inset: 54) }
        }
    }
}

private struct LowFromFridgeRow: View {
    let item: FoodItem
    let isLast: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onAdd) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(L.sunBg)
                        LSymbol(key: "plus", size: 14, weight: .heavy)
                            .foregroundStyle(L.sunFg)
                    }
                    .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.manrope(15, .heavy))
                            .kerning(-0.2)
                            .foregroundStyle(L.ink)
                        Text("Low in your fridge — tap to add")
                            .font(.manrope(12, .semibold))
                            .foregroundStyle(L.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            if !isLast { Hairline(inset: 54) }
        }
    }
}

private struct _ShoppingShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}
private struct _ShoppingSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

import SwiftUI

/// Shopping — progress card, sections of big-checkbox rows. Mirrors V2Shopping.
struct ShoppingView: View {
    @Environment(AppState.self) private var app
    @State private var newItemName = ""
    @State private var addingItem = false

    private var totalItems: Int { app.shopping.items.count }
    private var checked: Int { app.shopping.items.filter(\.checked).count }
    private var pct: Double { totalItems == 0 ? 0 : Double(checked) / Double(totalItems) }
    private var autoCount: Int { app.shopping.items.filter(\.auto).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BigHeader(title: "Shopping", sub: "\(autoCount) auto-added") {
                    HStack(spacing: -10) {
                        Avatar(name: "Sam", color: L.mint, size: 36)
                        Avatar(name: "Eva", color: L.pop, size: 36)
                    }
                }
                .padding(.horizontal, L.S.pad)

                progressCard
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 18)

                householdTip
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 16)

                ForEach(app.shopping.grouped(), id: \.section) { group in
                    sectionView(name: group.section, items: group.items)
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 22)
                }

                addItemBar
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 22)

                Color.clear.frame(height: 130)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .task {
            if let uid = app.auth.currentUserId, app.shopping.items.isEmpty {
                await app.shopping.reload(userId: uid)
            }
        }
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAINSBURY'S RUN · SATURDAY")
                        .font(.manrope(12, .heavy))
                        .tracking(0.6)
                        .foregroundStyle(L.cream.opacity(0.65))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(checked)")
                            .font(.manrope(44, .heavy))
                            .kerning(-1.6)
                            .foregroundStyle(L.cream)
                        Text("/ \(totalItems)")
                            .font(.manrope(18, .bold))
                            .foregroundStyle(L.cream.opacity(0.55))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("EST.")
                        .font(.manrope(12, .heavy))
                        .tracking(0.6)
                        .foregroundStyle(L.cream.opacity(0.65))
                    Text("£32.40")
                        .font(.manrope(28, .heavy))
                        .kerning(-1)
                        .foregroundStyle(L.cream)
                }
            }

            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(L.cream.opacity(0.12))
                    Capsule().fill(L.mint).frame(width: g.size.width * pct)
                }
            }
            .frame(height: 7)
            .padding(.top, 16)

            HStack {
                Text(pct >= 1 ? "All done — nice." : "\(totalItems - checked) left to grab.")
                    .font(.manrope(12.5, .semibold))
                    .foregroundStyle(L.cream.opacity(0.65))
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding(22)
        .background(L.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var householdTip: some View {
        HStack(spacing: 12) {
            Circle().fill(L.mint).frame(width: 8, height: 8)
                .opacity(0.85)
            Text("Sam is at the shop — checking off live.")
                .font(.manrope(13.5, .bold))
                .kerning(-0.1)
                .foregroundStyle(Color(hex: 0x2C4A1E))
            Spacer()
        }
        .padding(14)
        .background(L.mintBg, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sectionView(name: String, items: [ShoppingListItem]) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .lastTextBaseline) {
                Text(name)
                    .font(.manrope(18, .heavy))
                    .kerning(-0.5)
                    .foregroundStyle(L.ink)
                Spacer()
                Text("\(items.count)")
                    .font(.manrope(12, .heavy))
                    .foregroundStyle(L.ink.opacity(0.5))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { (i, item) in
                    BigShopRow(item: item, isLast: i == items.count - 1) {
                        Task { await app.shopping.toggle(item.id) }
                    }
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .modifier(_ShoppingShadow())
        }
    }

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
}

private struct _ShoppingShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}
private struct _ShoppingSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

/// Shopping row with a HUGE 30pt checkbox.
struct BigShopRow: View {
    let item: ShoppingListItem
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(item.checked ? Color.clear : L.ink.opacity(0.15), lineWidth: 2)
                    if item.checked {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(L.mint)
                        LSymbol(key: "check", size: 20, weight: .heavy).foregroundStyle(L.cream)
                    }
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.manrope(16, .bold))
                            .kerning(-0.3)
                            .foregroundStyle(item.checked ? L.ink.opacity(0.4) : L.ink)
                            .strikethrough(item.checked, color: L.ink.opacity(0.4))
                        if item.auto { AIDot(color: L.mint, size: 5) }
                    }
                    HStack(spacing: 8) {
                        Text(item.qty)
                            .font(.manrope(12.5, .semibold))
                            .foregroundStyle(L.ink.opacity(0.55))
                        if let r = item.forRecipe {
                            Text("· \(r)")
                                .font(.manrope(12.5, .semibold))
                                .foregroundStyle(L.ink.opacity(0.4))
                        }
                    }
                }

                Spacer()

                if let by = item.addedBy { Avatar(name: by, color: L.mint, size: 26) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(L.ink.opacity(0.07)).frame(height: 0.5).padding(.leading, 58)
            }
        }
    }
}

import SwiftUI

/// Recipe detail — hero FoodOrb, reason badge, stat row, ingredients, steps,
/// sticky cook CTA. Mirrors V2RecipeDetail.
struct RecipeDetailView: View {
    @Environment(AppState.self) private var app
    let recipe: Recipe
    let onClose: () -> Void

    @State private var servings = 2
    @State private var cooking = false
    @State private var stepIdx = 0
    @State private var addedToShoppingCount = 0

    private var match: RecipeMatch {
        RecipeMatcher.match(recipe: recipe, fridge: app.fridge.items)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                ZStack(alignment: .top) {
                    FoodOrb(foods: recipe.uses, color: recipe.color, accent: recipe.accent, height: 360, radius: 0)
                    HStack {
                        BigIconBtn(icon: "chevronL", tone: .light, action: onClose)
                        Spacer()
                        HStack(spacing: 10) {
                            BigIconBtn(icon: "heart") {}
                            BigIconBtn(icon: "dots") {}
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 50)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags, id: \.self) { t in
                            LPill(tone: .mint) { Text(t) }
                        }
                    }
                    .padding(.bottom, 10)

                    Text(recipe.title)
                        .font(.manrope(30, .heavy))
                        .kerning(-1)
                        .foregroundStyle(L.ink)
                    Text(recipe.subtitle)
                        .font(.manrope(15, .medium))
                        .foregroundStyle(L.ink.opacity(0.55))
                        .padding(.top, 4)

                    // Reason badge — quietly AI, swaps to a "live" reason
                    // based on the user's actual fridge if one applies.
                    HStack(spacing: 12) {
                        AIDot(color: L.pop, size: 8)
                        Text(liveReason)
                            .font(.manrope(13.5, .bold))
                            .kerning(-0.1)
                            .foregroundStyle(L.popDark)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(L.popBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.top, 16)

                    // Stats row
                    HStack(spacing: 0) {
                        BigStat(big: "\(recipe.timeMinutes)", sm: "min", label: "Cook", divider: false)
                        BigStat(big: "\(recipe.kcal)", sm: "kcal", label: "Energy", divider: true)
                        BigStat(big: "\(recipe.protein)", sm: "g", label: "Protein", divider: true)
                        BigStat(big: recipe.difficulty, sm: "", label: "Level", divider: true)
                    }
                    .padding(.vertical, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .modifier(_DetailCardShadow())
                    .padding(.top, 16)

                    // Ingredients — live state from the user's fridge.
                    let liveIngredients = match.ingredients
                    let inFridgeCount = liveIngredients.filter(\.have).count

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Ingredients")
                                .font(.manrope(22, .heavy))
                                .kerning(-0.5)
                                .foregroundStyle(L.ink)
                            HStack(spacing: 0) {
                                Text("\(inFridgeCount)")
                                    .font(.manrope(13, .heavy))
                                    .foregroundStyle(L.mint)
                                Text(" / \(liveIngredients.count) in fridge")
                                    .font(.manrope(13, .semibold))
                                    .foregroundStyle(L.ink.opacity(0.55))
                                if !match.missingIngredients.isEmpty {
                                    Text(" · \(match.missingIngredients.count) to buy")
                                        .font(.manrope(13, .semibold))
                                        .foregroundStyle(L.pop)
                                }
                            }
                        }
                        Spacer()
                        BigStepper(value: $servings)
                    }
                    .padding(.top, 28)

                    VStack(spacing: 0) {
                        ForEach(Array(liveIngredients.enumerated()), id: \.element.id) { (i, ing) in
                            ingredientRow(ing, isLast: i == liveIngredients.count - 1)
                        }
                    }
                    .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .modifier(_DetailCardShadow())
                    .padding(.top, 14)

                    if !match.missingIngredients.isEmpty {
                        Button { addMissingToShoppingList() } label: {
                            HStack {
                                LSymbol(key: "cart", size: 16, weight: .heavy)
                                Text(addedToShoppingCount > 0
                                     ? "\(addedToShoppingCount) added to your list"
                                     : "Add \(match.missingIngredients.count) missing to shopping list")
                                Spacer()
                                LSymbol(key: "arrowR", size: 14, weight: .heavy)
                            }
                            .font(.manrope(14, .heavy))
                            .foregroundStyle(addedToShoppingCount > 0 ? L.mint : L.pop)
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background((addedToShoppingCount > 0 ? L.mintBg : L.popBg), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 10)
                        .disabled(addedToShoppingCount > 0)
                    }

                    // Steps
                    Text("Steps")
                        .font(.manrope(22, .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(L.ink)
                        .padding(.top, 28)
                        .padding(.bottom, 12)

                    VStack(spacing: 10) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { (i, step) in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(L.ink)
                                    Text("\(i + 1)")
                                        .font(.manrope(16, .heavy))
                                        .foregroundStyle(L.cream)
                                }
                                .frame(width: 36, height: 36)

                                Text(step)
                                    .font(.manrope(14.5, .medium))
                                    .lineSpacing(3)
                                    .foregroundStyle(L.ink)
                                    .padding(.top, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .modifier(_DetailCardShadow())
                        }
                    }

                    Color.clear.frame(height: 130)
                }
                .padding(.horizontal, L.S.pad)
                .padding(.top, 24)
                .background(L.paper, in: RoundedRectangle(cornerRadius: 32, style: .continuous).offset(y: -32))
            }
            .ignoresSafeArea(edges: .top)
            .background(L.paper.ignoresSafeArea())

            BigCTA(title: cooking ? "Next step" : "Start cooking", icon: "flame", kind: .primary) {
                if cooking {
                    stepIdx = min(stepIdx + 1, recipe.steps.count - 1)
                } else {
                    cooking = true
                    // Cooking starts → auto-add anything missing to the shopping list.
                    addMissingToShoppingList()
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
        }
        .background(L.paper.ignoresSafeArea())
    }

    private var liveReason: String {
        if !match.useSoonIngredients.isEmpty {
            let names = match.useSoonIngredients.prefix(2).map(\.name).joined(separator: " + ")
            return "Uses your \(names) — they need eating soon."
        }
        if match.matchPct == 100 {
            return "You have every ingredient — start now."
        }
        if !match.missingIngredients.isEmpty {
            return "\(match.missingIngredients.count) missing — Levla can add them to your list."
        }
        return recipe.why
    }

    private func addMissingToShoppingList() {
        guard let userId = app.auth.currentUserId else { return }
        let alreadyOnList = Set(app.shopping.items.map { $0.name.lowercased() })
        let toAdd = match.missingIngredients.filter { !alreadyOnList.contains($0.name.lowercased()) }
        guard !toAdd.isEmpty else {
            addedToShoppingCount = 0
            return
        }
        addedToShoppingCount = toAdd.count
        Task {
            for ing in toAdd {
                let item = ShoppingListItem(
                    id: UUID(),
                    userId: userId,
                    name: ing.name,
                    qty: ing.amount,
                    section: sectionFor(foodKey: ing.foodKey),
                    auto: true,
                    forRecipe: recipe.title,
                    checked: false,
                    inFridge: false,
                    addedBy: nil,
                    createdAt: Date()
                )
                await app.shopping.add(item)
            }
        }
    }

    private func sectionFor(foodKey: String) -> String {
        switch foodKey {
        case "milk", "yogurt", "butter", "feta", "egg": return "Dairy"
        case "spinach", "broccoli", "tomato", "carrot", "pepper", "lemon",
             "garlic", "onion", "avocado":                return "Produce"
        case "chicken", "salmon", "beef":                 return "Meat"
        case "rice", "pasta", "oil", "pesto", "parmesan": return "Pantry"
        case "bread":                                     return "Bakery"
        case "wine", "water":                             return "Drinks"
        default:                                          return "Other"
        }
    }

    @ViewBuilder
    private func ingredientRow(_ ing: RecipeIngredient, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            FoodTile(food: ing.foodKey, size: 44, radius: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(ing.name)
                    .font(.manrope(15, .bold))
                    .kerning(-0.3)
                    .foregroundStyle(ing.have ? L.ink : L.ink.opacity(0.5))
                Text(ing.amount)
                    .font(.manrope(12.5, .semibold))
                    .foregroundStyle(L.ink.opacity(0.5))
            }
            Spacer()
            if ing.have {
                if ing.useSoon {
                    LPill(tone: .pop) { Text("use today") }
                } else if ing.low {
                    LPill(tone: .sun) { Text("low") }
                } else {
                    ZStack {
                        Circle().fill(L.mintBg)
                        LSymbol(key: "check", size: 16, weight: .heavy).foregroundStyle(L.mint)
                    }
                    .frame(width: 28, height: 28)
                }
            } else {
                LPill(tone: .ink) {
                    LSymbol(key: "cart", size: 12, weight: .heavy)
                    Text(" Buy")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(L.ink.opacity(0.06)).frame(height: 0.5).padding(.leading, 74)
            }
        }
    }
}

private struct _DetailCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

struct BigStat: View {
    let big: String
    let sm: String
    let label: String
    let divider: Bool

    var body: some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(big).font(.manrope(22, .heavy)).kerning(-0.6).foregroundStyle(L.ink)
                if !sm.isEmpty {
                    Text(sm).font(.manrope(11, .heavy)).foregroundStyle(L.ink.opacity(0.5))
                }
            }
            Text(label.uppercased())
                .font(.manrope(10.5, .heavy))
                .tracking(0.4)
                .foregroundStyle(L.ink.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            if divider {
                Rectangle().fill(L.ink.opacity(0.08)).frame(width: 0.5)
            }
        }
    }
}

struct BigStepper: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 0) {
            Button { value = max(1, value - 1) } label: {
                LSymbol(key: "minus", size: 16, weight: .heavy)
                    .foregroundStyle(L.ink)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text("\(value) serv")
                .font(.manrope(14, .heavy))
                .kerning(-0.2)
                .foregroundStyle(L.ink)
                .frame(minWidth: 46)
            Button { value += 1 } label: {
                LSymbol(key: "plus", size: 16, weight: .heavy)
                    .foregroundStyle(L.cream)
                    .frame(width: 34, height: 34)
                    .background(L.ink, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(.white, in: Capsule())
        .modifier(_StepperShadow())
    }
}

private struct _StepperShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

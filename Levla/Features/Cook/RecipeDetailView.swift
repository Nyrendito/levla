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

    /// LLM returns ingredient amounts for a base serving count. We assume 2
    /// (the same as the stepper's default), and scale the displayed amount
    /// by `servings / baseServings` so changing the stepper actually moves
    /// the numbers.
    private let baseServings = 2
    private var scaleFactor: Double { Double(servings) / Double(baseServings) }

    private var match: RecipeMatch {
        RecipeMatcher.match(recipe: recipe, fridge: app.fridge.items)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                ZStack(alignment: .top) {
                    FoodOrb(foods: recipe.uses, color: recipe.color, accent: recipe.accent, height: 360, radius: 0, recipe: recipe)
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

                    // Reason note (Lifesum-style quiet body copy).
                    Text(liveReason)
                        .font(.manrope(14, .semibold))
                        .foregroundStyle(L.muted)
                        .padding(.top, 14)

                    nutritionalInfoBlock
                        .padding(.top, 24)

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
                            ingredientRow(ing, isLast: i == liveIngredients.count - 1, scale: scaleFactor)
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

            stickyCTA
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
        }
        .background(L.paper.ignoresSafeArea())
    }

    // MARK: - Sticky CTA — three-stage flow

    /// Three-state bottom button so the user only "logs" the meal when
    /// they actually finish cooking. The old single CTA wrote a
    /// cooked_entries row the moment they tapped "Start cooking" — which
    /// inflated today's macros for recipes they just glanced at.
    ///
    /// State machine:
    ///   .notStarted → "Start cooking"           → enters cooking mode at step 1, adds missing to shopping
    ///   .cooking    → "Next step"               → advances stepIdx
    ///   .cooking @ final step → "Log this meal" → writes the cooked_entry (servings-scaled)
    ///   .logged     → "Logged ✓" (disabled)        → confirmation; closes after delay
    @ViewBuilder
    private var stickyCTA: some View {
        switch cookingPhase {
        case .notStarted:
            BigCTA(title: "Start cooking", icon: "flame", kind: .primary) {
                cooking = true
                stepIdx = 0
                addMissingToShoppingList()
            }
        case .cooking:
            BigCTA(title: "Next step", icon: "arrowR", kind: .ink) {
                stepIdx = min(stepIdx + 1, recipe.steps.count - 1)
            }
        case .readyToLog:
            BigCTA(title: "Log this meal", icon: "check", kind: .primary) {
                logCookedEntry()
            }
        case .logged:
            BigCTA(title: "Logged ✓", icon: nil, kind: .light) { onClose() }
        }
    }

    private enum CookingPhase { case notStarted, cooking, readyToLog, logged }

    private var cookingPhase: CookingPhase {
        if didLog { return .logged }
        guard cooking else { return .notStarted }
        if stepIdx >= recipe.steps.count - 1 { return .readyToLog }
        return .cooking
    }

    @State private var didLog = false

    private func logCookedEntry() {
        guard let uid = app.auth.currentUserId, !didLog else { return }
        Task {
            await app.cooked.log(recipe: recipe, servings: servings, userId: uid)
            didLog = true
        }
    }

    // MARK: - Lifesum nutritional info block

    private var totalEnergy: Double {
        let c = Double(recipe.carbs) * 4
        let f = Double(recipe.fat) * 9
        let p = Double(recipe.protein) * 4
        return max(1, c + f + p)
    }
    private var carbsPct:   Double { (Double(recipe.carbs) * 4) / totalEnergy }
    private var fatPct:     Double { (Double(recipe.fat) * 9) / totalEnergy }
    private var proteinPct: Double { (Double(recipe.protein) * 4) / totalEnergy }

    @ViewBuilder
    private var nutritionalInfoBlock: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(text: "Nutritional information")

            HStack(spacing: 14) {
                LSNutritionDial(label: "Carbs",   percent: carbsPct,   color: L.macroCarbs)
                LSNutritionDial(label: "Protein", percent: proteinPct, color: L.macroProtein)
                LSNutritionDial(label: "Fat",     percent: fatPct,     color: L.macroFat)
            }
            .frame(maxWidth: .infinity)

            // Hairlined macro list, Lifesum-style: label left, value right.
            VStack(spacing: 0) {
                NutrientRow(label: "Kcal",    value: "\(recipe.kcal) kcal", isLast: false)
                NutrientRow(label: "Protein", value: "\(recipe.protein) g", isLast: false)
                NutrientRow(label: "Carbs",   value: "\(recipe.carbs) g",   isLast: false)
                NutrientRow(label: "Fat",     value: "\(recipe.fat) g",     isLast: true)
            }
        }
    }

    // MARK: - Reason / shopping / ingredient row

    private var liveReason: String {
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
    fileprivate func ingredientRow(_ ing: RecipeIngredient, isLast: Bool, scale: Double) -> some View {
        let displayAmount = IngredientScaler.scale(ing.amount, factor: scale)
        HStack(spacing: 14) {
            FoodTile(food: ing.foodKey, size: 40, radius: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(ing.name)
                    .font(.manrope(15, .heavy))
                    .kerning(-0.2)
                    .foregroundStyle(ing.have ? L.ink : L.muted)
                Text(displayAmount)
                    .font(.manrope(12, .semibold))
                    .foregroundStyle(L.muted)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.18), value: displayAmount)
            }
            Spacer()
            if ing.have {
                if ing.low {
                    Text("LOW")
                        .font(.manrope(10, .heavy)).tracking(1.2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(L.sunBg, in: Capsule())
                        .foregroundStyle(L.sunFg)
                } else {
                    ZStack {
                        Circle().fill(L.brandBg)
                        LSymbol(key: "check", size: 14, weight: .heavy).foregroundStyle(L.brand)
                    }
                    .frame(width: 26, height: 26)
                }
            } else {
                HStack(spacing: 4) {
                    LSymbol(key: "cart", size: 11, weight: .heavy)
                    Text("BUY")
                }
                .font(.manrope(10, .heavy)).tracking(1.2)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(L.ink, in: Capsule())
                .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if !isLast {
                Hairline(inset: 70)
            }
        }
    }
}

// MARK: - Nutrition primitives

/// Lifesum-style large ring + percent + label.
private struct LSNutritionDial: View {
    let label: String
    let percent: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(L.inset, lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, percent))))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.manrope(16, .heavy))
                    .foregroundStyle(L.ink)
            }
            .frame(width: 72, height: 72)
            Text(label)
                .font(.manrope(12, .heavy))
                .tracking(0.4)
                .foregroundStyle(L.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct NutrientRow: View {
    let label: String
    let value: String
    let isLast: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.manrope(15, .heavy))
                    .foregroundStyle(L.ink)
                Spacer()
                Text(value)
                    .font(.manrope(15, .heavy))
                    .foregroundStyle(L.ink)
            }
            .padding(.vertical, 14)
            if !isLast { Hairline() }
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

/// Servings stepper — balanced pill with matching outlined - / + buttons on
/// either side of a centered count + label. Replaces the older off-center
/// "minus is plain, plus is filled dark" combo which felt visually unbalanced.
struct BigStepper: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 0) {
            stepBtn(icon: "minus", enabled: value > 1) {
                guard value > 1 else { return }
                withAnimation(.easeInOut(duration: 0.15)) { value -= 1 }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.manrope(15.5, .heavy))
                    .foregroundStyle(L.ink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.18), value: value)
                Text(value == 1 ? "serving" : "servings")
                    .font(.manrope(11, .heavy))
                    .tracking(0.3)
                    .foregroundStyle(L.muted)
            }
            .frame(minWidth: 78)
            .padding(.horizontal, 4)

            stepBtn(icon: "plus", enabled: true) {
                withAnimation(.easeInOut(duration: 0.15)) { value += 1 }
            }
        }
        .padding(4)
        .background(.white, in: Capsule())
        .overlay(Capsule().strokeBorder(L.hairline, lineWidth: 0.5))
        .modifier(_StepperShadow())
    }

    private func stepBtn(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(L.ink.opacity(enabled ? 0.12 : 0.06), lineWidth: 1)
                LSymbol(key: icon, size: 13, weight: .heavy)
                    .foregroundStyle(enabled ? L.ink : L.ink.opacity(0.35))
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .tapPress()
    }
}

private struct _StepperShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

import SwiftUI

/// Home — a decision assistant, not a dashboard.
/// Answers ONE question: "What should I cook before my food goes bad?"
///
/// Structure (top to bottom):
/// 1. Levla wordmark
/// 2. "Tonight — cook X" hero (the top-ranked recipe)
/// 3. Optional featured recipe card
/// 4. "Use these first" — up to 3 urgent items, as chips
/// 5. Big Scan fridge CTA
/// 6. Optional Expiring soon banner (only when something's urgent)
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var openedRecipe: Recipe?

    private var matches: [RecipeMatch] {
        RecipeMatcher.rank(recipes: app.recipes.recipes, fridge: app.fridge.items)
    }
    private var topRecipe: RecipeMatch? { matches.first }

    private var useFirst: [FoodItem] {
        app.fridge.items
            .filter { $0.status == .today || $0.status == .soon }
            .sorted(by: { $0.daysLeft < $1.daysLeft })
            .prefix(3)
            .map { $0 }
    }

    private var urgentCount: Int { useFirst.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandRow
                heroHeadline
                if !app.fridge.items.isEmpty, let m = topRecipe {
                    FeaturedRecipeCard(match: m) { openedRecipe = m.recipe }
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 14)
                }
                if !useFirst.isEmpty {
                    useFirstSection
                        .padding(.top, 28)
                }
                BigCTA(title: "Scan fridge", icon: "camera", kind: .primary) {
                    app.presentingScan = .fridge
                }
                .padding(.horizontal, L.S.pad)
                .padding(.top, 28)

                if urgentCount > 0 {
                    expiringBanner.padding(.top, 14)
                }

                Color.clear.frame(height: 140)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .sheet(item: $openedRecipe) { recipe in
            RecipeDetailView(recipe: recipe) { openedRecipe = nil }
        }
        .task {
            if let uid = app.auth.currentUserId, app.fridge.items.isEmpty {
                await app.fridge.reload(userId: uid)
            }
            await app.recipes.reload(for: app.fridge.items)
        }
    }

    // MARK: - Brand

    private var brandRow: some View {
        HStack {
            Text("Levla")
                .font(.manrope(26, .heavy))
                .kerning(-0.8)
                .foregroundStyle(L.ink)
            Spacer()
        }
        .padding(.horizontal, L.S.pad)
        .padding(.top, 56)
    }

    // MARK: - Hero

    private var heroHeadline: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TONIGHT")
                .font(.mono(11))
                .tracking(1.2)
                .foregroundStyle(L.ink.opacity(0.4))

            if app.fridge.items.isEmpty {
                Text("Scan your fridge\nto get started.")
                    .font(.manrope(38, .heavy))
                    .kerning(-1.3)
                    .lineSpacing(2)
                    .foregroundStyle(L.ink)
            } else if let m = topRecipe {
                Text("Cook \(m.recipe.title).")
                    .font(.manrope(34, .heavy))
                    .kerning(-1.2)
                    .lineSpacing(2)
                    .foregroundStyle(L.ink)
                Text(reasonLine(for: m))
                    .font(.manrope(15, .medium))
                    .foregroundStyle(L.ink.opacity(0.55))
                    .padding(.top, 2)
            } else {
                Text("Nothing to cook yet.")
                    .font(.manrope(34, .heavy))
                    .kerning(-1.2)
                    .foregroundStyle(L.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, L.S.pad)
        .padding(.top, 26)
    }

    private func reasonLine(for m: RecipeMatch) -> String {
        if !m.useSoonIngredients.isEmpty {
            let names = m.useSoonIngredients.prefix(2).map(\.name).joined(separator: " + ")
            return "Uses your \(names) — they expire soon."
        }
        if m.matchPct == 100 {
            return "You have every ingredient."
        }
        return "\(m.recipe.timeMinutes) min · \(m.missingIngredients.count) missing"
    }

    // MARK: - Use first

    private var useFirstSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("USE THESE FIRST")
                .font(.mono(11))
                .tracking(1.2)
                .foregroundStyle(L.ink.opacity(0.4))
                .padding(.horizontal, L.S.pad)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(useFirst) { item in
                        UseFirstChip(item: item)
                    }
                }
                .padding(.horizontal, L.S.pad)
            }
        }
    }

    // MARK: - Expiring banner

    private var expiringBanner: some View {
        Button { app.selectedTab = .fridge } label: {
            HStack(spacing: 12) {
                Circle().fill(L.rose).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(urgentCount) item\(urgentCount == 1 ? "" : "s") need attention")
                        .font(.manrope(14, .heavy))
                        .kerning(-0.2)
                        .foregroundStyle(L.ink)
                    Text("Expiring soon — tap to review")
                        .font(.manrope(12.5, .semibold))
                        .foregroundStyle(L.ink.opacity(0.55))
                }
                Spacer()
                LSymbol(key: "arrowR", size: 16, weight: .heavy)
                    .foregroundStyle(L.ink.opacity(0.45))
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_HomeCardShadow())
        .padding(.horizontal, L.S.pad)
        .tapPress()
    }
}

// MARK: - Featured recipe card

private struct FeaturedRecipeCard: View {
    let match: RecipeMatch
    let onTap: () -> Void

    private var recipe: Recipe { match.recipe }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                FoodOrb(foods: recipe.uses, color: recipe.color, accent: recipe.accent, height: 200, radius: 0, label: recipe.uses.first)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous).offset(y: 1))

                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.title)
                        .font(.manrope(20, .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(L.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 10) {
                        Label("\(recipe.timeMinutes) min", systemImage: "clock")
                            .font(.manrope(13, .bold))
                            .foregroundStyle(L.ink.opacity(0.6))
                        Text("·").foregroundStyle(L.ink.opacity(0.25))
                        Text("Uses \(match.recipe.uses.count - match.missingIngredients.count) of yours")
                            .font(.manrope(13, .bold))
                            .foregroundStyle(L.ink.opacity(0.6))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_HomeCardShadow())
        .tapPress()
    }
}

// MARK: - Use first chip

private struct UseFirstChip: View {
    let item: FoodItem

    private var label: String {
        if item.daysLeft <= 0 { return "today" }
        return "\(item.daysLeft)d left"
    }
    private var labelColor: Color {
        item.daysLeft <= 0 ? L.rose : L.pop
    }

    var body: some View {
        HStack(spacing: 8) {
            FoodTile(food: item.foodKey, size: 32, radius: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.manrope(13, .heavy))
                    .kerning(-0.2)
                    .foregroundStyle(L.ink)
                    .lineLimit(1)
                Text(label)
                    .font(.manrope(11, .bold))
                    .foregroundStyle(labelColor)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(_HomeChipShadow())
    }
}

private struct _HomeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

private struct _HomeChipShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

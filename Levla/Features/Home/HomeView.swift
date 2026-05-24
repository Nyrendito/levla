import SwiftUI

/// Home — driven by what the user actually cooked today + what they could
/// cook next. No fake expiry tracking, no dashboard noise.
///
/// Top to bottom:
/// 1. Levla wordmark
/// 2. Today's macros (kcal + carbs/fat/protein) — Cal-AI-style stacked bar
/// 3. "COOK TONIGHT" label + featured recipe card (details on the card itself)
/// 4. "RECENTLY ADDED" — last 3 scans
/// 5. Big "Scan fridge" CTA
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var openedRecipe: Recipe?

    private var matches: [RecipeMatch] {
        RecipeMatcher.rank(recipes: app.recipes.recipes, fridge: app.fridge.items)
    }
    private var topRecipe: RecipeMatch? { matches.first }

    private var recentlyAdded: [FoodItem] {
        Array(
            app.fridge.items
                .sorted { $0.addedAt > $1.addedAt }
                .prefix(3)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                brandRow

                // Macros card up top — Cal-AI-style daily totals.
                MacrosBar(
                    kcal:    app.cooked.todayKcal,
                    protein: app.cooked.todayProtein,
                    carbs:   app.cooked.todayCarbs,
                    fat:     app.cooked.todayFat
                )
                .padding(.horizontal, L.S.pad)
                .padding(.top, 22)

                if !app.fridge.items.isEmpty, let m = topRecipe {
                    sectionLabel("COOK TONIGHT")
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 30)
                    FeaturedRecipeCard(match: m) { openedRecipe = m.recipe }
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 10)
                } else if app.fridge.items.isEmpty {
                    EmptyFridgeHint()
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 28)
                }

                if !recentlyAdded.isEmpty {
                    recentlyAddedSection.padding(.top, 30)
                }

                BigCTA(title: "Scan fridge", icon: "camera", kind: .primary) {
                    app.presentingScan = .fridge
                }
                .padding(.horizontal, L.S.pad)
                .padding(.top, 28)

                Color.clear.frame(height: 140)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .sheet(item: $openedRecipe) { recipe in
            RecipeDetailView(recipe: recipe) { openedRecipe = nil }
        }
        .task {
            if let uid = app.auth.currentUserId {
                if app.fridge.items.isEmpty { await app.fridge.reload(userId: uid) }
                await app.cooked.reloadToday(userId: uid)
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

    // MARK: - Recently added

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENTLY ADDED")
                    .font(.mono(11)).tracking(1.2)
                    .foregroundStyle(L.ink.opacity(0.4))
                Spacer()
                Button { app.selectedTab = .fridge } label: {
                    Text("See all")
                        .font(.manrope(12, .heavy))
                        .foregroundStyle(L.ink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, L.S.pad)

            VStack(spacing: 0) {
                ForEach(Array(recentlyAdded.enumerated()), id: \.element.id) { (i, item) in
                    RecentRow(item: item, isLast: i == recentlyAdded.count - 1)
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .modifier(_HomeCardShadow())
            .padding(.horizontal, L.S.pad)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.mono(11)).tracking(1.2)
            .foregroundStyle(L.ink.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Featured recipe card

/// All the details live ON the card — title, time, kcal, and what's missing.
/// The headline above is just "COOK TONIGHT".
private struct FeaturedRecipeCard: View {
    let match: RecipeMatch
    let onTap: () -> Void

    private var recipe: Recipe { match.recipe }

    private var missing: Int { match.missingIngredients.count }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                FoodOrb(foods: recipe.uses, color: recipe.color, accent: recipe.accent, height: 200, radius: 0, label: recipe.uses.first)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous).offset(y: 1))

                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title)
                        .font(.manrope(22, .heavy))
                        .kerning(-0.5)
                        .foregroundStyle(L.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        metaPill(icon: "clock", text: "\(recipe.timeMinutes) min")
                        metaPill(icon: "flame", text: "\(recipe.kcal) kcal")
                        if missing == 0 {
                            metaPill(icon: "check", text: "All in fridge", tone: .mint)
                        } else {
                            metaPill(icon: "cart", text: "\(missing) to buy", tone: .pop)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_HomeCardShadow())
        .tapPress()
    }

    private enum Tone { case neutral, mint, pop }

    @ViewBuilder
    private func metaPill(icon: String, text: String, tone: Tone = .neutral) -> some View {
        let (fg, bg): (Color, Color) = {
            switch tone {
            case .neutral: return (L.ink.opacity(0.6), L.ink.opacity(0.04))
            case .mint:    return (L.mint, L.mintBg)
            case .pop:     return (L.pop, L.popBg)
            }
        }()
        HStack(spacing: 5) {
            LSymbol(key: icon, size: 12, weight: .heavy)
            Text(text)
        }
        .font(.manrope(12.5, .heavy))
        .kerning(-0.1)
        .foregroundStyle(fg)
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(bg, in: Capsule())
    }
}

// MARK: - Recently-added row

private struct RecentRow: View {
    let item: FoodItem
    let isLast: Bool

    private var whenLabel: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: item.addedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            FoodTile(food: item.foodKey, size: 40, radius: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.manrope(15, .heavy))
                    .kerning(-0.2)
                    .foregroundStyle(L.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.qty)
                    Text("·").foregroundStyle(L.ink.opacity(0.25))
                    Text(whenLabel)
                }
                .font(.manrope(12, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
            }
            Spacer()
            if item.status == .low {
                Text("low")
                    .font(.manrope(11, .heavy))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(L.sun, in: Capsule())
                    .foregroundStyle(L.cream)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(L.ink.opacity(0.07)).frame(height: 0.5).padding(.leading, 68)
            }
        }
    }
}

// MARK: - Empty state

private struct EmptyFridgeHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scan your fridge")
                .font(.manrope(22, .heavy))
                .kerning(-0.5)
                .foregroundStyle(L.ink)
            Text("Levla suggests what to cook based on what you already have.")
                .font(.manrope(14, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

private struct _HomeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

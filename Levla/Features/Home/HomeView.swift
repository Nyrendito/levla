import SwiftUI

/// Home — a decision assistant, not a dashboard.
/// One question: "What should I cook with what I have?"
///
/// Top to bottom:
/// 1. Levla wordmark
/// 2. "Tonight — cook X" hero (top-ranked recipe)
/// 3. Featured recipe card
/// 4. "Recently added" — last 3 things scanned in
/// 5. Big Scan fridge CTA
///
/// Deliberately removed: expiry chips, "use today / 2d left" pills,
/// "expiring soon" banner, "use first" section, freshness tracker dials.
/// We can't reliably infer time-based expiry from a fridge photo, so we
/// don't pretend to.
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
                heroHeadline
                if !app.fridge.items.isEmpty, let m = topRecipe {
                    FeaturedRecipeCard(match: m) { openedRecipe = m.recipe }
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 14)
                }
                if !recentlyAdded.isEmpty {
                    recentlyAddedSection
                        .padding(.top, 28)
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
        if m.matchPct == 100 {
            return "You have every ingredient."
        }
        let have = m.recipe.ingredients.count - m.missingIngredients.count
        return "\(m.recipe.timeMinutes) min · \(have) of \(m.recipe.ingredients.count) in your fridge"
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

private struct _HomeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

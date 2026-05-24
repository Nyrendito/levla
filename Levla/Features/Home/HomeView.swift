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
    @State private var mealPage: Int = 0

    private var matches: [RecipeMatch] {
        RecipeMatcher.rank(recipes: app.recipes.recipes, fridge: app.fridge.items)
    }

    /// 3-page carousel: best breakfast, best lunch, best dinner.
    /// Each page is the top-ranked recipe for that meal type.
    private var dailyMeals: [RecipeMatch] {
        let order: [MealType] = [.breakfast, .lunch, .dinner]
        return order.compactMap { type in
            matches.first(where: { $0.recipe.mealType == type })
        }
    }

    /// Pick the index that matches the user's current time of day.
    /// 5:00-10:59 → breakfast (0)
    /// 11:00-15:59 → lunch (1)
    /// 16:00-04:59 → dinner (2)
    private var currentMealIndex: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5...10:  return 0
        case 11...15: return 1
        default:      return 2
        }
    }

    private var currentMealLabel: String {
        let index = min(mealPage, max(0, dailyMeals.count - 1))
        guard dailyMeals.indices.contains(index) else { return "WHAT TO COOK" }
        return dailyMeals[index].recipe.mealType.displayName.uppercased() + " TODAY"
    }

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

                // Macros card up top — Cal-AI-style daily totals against
                // the user's personalized goals (Mifflin-St Jeor + activity
                // + goal-adjusted kcal, with macro splits derived from it).
                MacrosBar(
                    kcal:        app.cooked.todayKcal,
                    protein:     app.cooked.todayProtein,
                    carbs:       app.cooked.todayCarbs,
                    fat:         app.cooked.todayFat,
                    kcalGoal:    app.currentProfile?.dailyKcalGoal,
                    proteinGoal: app.currentProfile?.dailyProteinGoal,
                    carbsGoal:   app.currentProfile?.dailyCarbsGoal,
                    fatGoal:     app.currentProfile?.dailyFatGoal
                )
                .padding(.horizontal, L.S.pad)
                .padding(.top, 22)

                if !app.fridge.items.isEmpty, !dailyMeals.isEmpty {
                    sectionLabel(currentMealLabel)
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 30)

                    MealCarousel(
                        meals: dailyMeals,
                        page: $mealPage,
                        onOpen: { openedRecipe = $0 }
                    )
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
            await app.recipes.reload(for: app.fridge.items, profile: app.currentProfile)
            mealPage = currentMealIndex
        }
    }

    // MARK: - Brand

    private var brandRow: some View {
        HStack(alignment: .center) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("Levla")
                    .font(.manrope(24, .heavy))
                    .kerning(-0.4)
                    .foregroundStyle(L.brand)
                Text("®")
                    .font(.manrope(10, .semibold))
                    .foregroundStyle(L.brand)
                    .baselineOffset(8)
            }
            Spacer()
            BigIconBtn(icon: "user") { app.presentingProfile = true }
                .opacity(0.95)
        }
        .padding(.horizontal, L.S.pad)
        .padding(.top, 18)
    }

    // MARK: - Recently added

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(text: "Recently added")
                Spacer()
                Button { app.selectedTab = .fridge } label: {
                    Text("SEE ALL")
                        .font(.manrope(11, .heavy))
                        .tracking(1.4)
                        .foregroundStyle(L.brand)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, L.S.pad)

            VStack(spacing: 0) {
                ForEach(Array(recentlyAdded.enumerated()), id: \.element.id) { (i, item) in
                    RecentRow(item: item, isLast: i == recentlyAdded.count - 1)
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

    private func sectionLabel(_ text: String) -> some View {
        SectionLabel(text: text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Meal carousel (3-page swipeable)

private struct MealCarousel: View {
    let meals: [RecipeMatch]
    @Binding var page: Int
    let onOpen: (Recipe) -> Void

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $page) {
                ForEach(Array(meals.enumerated()), id: \.element.id) { (i, match) in
                    FeaturedRecipeCard(match: match) { onOpen(match.recipe) }
                        .padding(.horizontal, L.S.pad)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            HStack(spacing: 7) {
                ForEach(0..<meals.count, id: \.self) { i in
                    Circle()
                        .fill(i == page ? L.ink : L.ink.opacity(0.20))
                        .frame(width: i == page ? 9 : 7, height: i == page ? 9 : 7)
                        .animation(.easeInOut(duration: 0.18), value: page)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: page)
    }
}

// MARK: - Featured recipe card

/// Lifesum-style recipe card — square hero image dominant, title and
/// kcal below, heart toggle bottom-right. Clean white card, no heavy
/// shadows, hairline border for definition.
private struct FeaturedRecipeCard: View {
    let match: RecipeMatch
    let onTap: () -> Void

    @State private var favourited = false

    private var recipe: Recipe { match.recipe }
    private var missing: Int { match.missingIngredients.count }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Hero. Square aspect; auto-fetches the recipe's generated
                // image via ImageCacheService, falls back to the abstract
                // orb wash while loading / when image gen is unavailable.
                FoodOrb(
                    foods: recipe.uses,
                    color: recipe.color,
                    accent: recipe.accent,
                    height: 210,
                    radius: 0,
                    recipe: recipe
                )
                .overlay(alignment: .topTrailing) {
                    if missing == 0 {
                        Text("ALL IN FRIDGE")
                            .font(.manrope(10, .heavy))
                            .tracking(1.2)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(L.brand, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(12)
                    } else {
                        Text("\(missing) TO BUY")
                            .font(.manrope(10, .heavy))
                            .tracking(1.2)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(L.pop, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(12)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(recipe.title)
                        .font(.manrope(20, .heavy))
                        .kerning(-0.4)
                        .foregroundStyle(L.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(alignment: .center) {
                        HStack(spacing: 14) {
                            Text("\(recipe.kcal) KCAL")
                                .font(.manrope(11.5, .heavy))
                                .tracking(1.4)
                                .foregroundStyle(L.muted)
                            Text("·").foregroundStyle(L.muted.opacity(0.5))
                            Text("\(recipe.timeMinutes) MIN")
                                .font(.manrope(11.5, .heavy))
                                .tracking(1.4)
                                .foregroundStyle(L.muted)
                        }
                        Spacer()
                        HeartToggle(isOn: $favourited)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(_HomeCardShadow())
        .tapPress()
    }
}

/// Heart icon toggle. Outline when off, coral filled when on.
struct HeartToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack {
                Image(systemName: isOn ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isOn ? L.heart : L.muted)
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
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
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                FoodTile(food: item.foodKey, size: 40, radius: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.manrope(15, .heavy))
                        .kerning(-0.2)
                        .foregroundStyle(L.ink)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(item.qty)
                        Text("·").foregroundStyle(L.muted.opacity(0.4))
                        Text(whenLabel)
                    }
                    .font(.manrope(12, .semibold))
                    .foregroundStyle(L.muted)
                }
                Spacer()
                if item.status == .low {
                    Text("LOW")
                        .font(.manrope(10, .heavy))
                        .tracking(1.2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(L.sunBg, in: Capsule())
                        .foregroundStyle(L.sunFg)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Hairline(inset: 70)
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

import SwiftUI

/// Home — tracking-style dashboard: brand row, 7-day strip, swipeable stat
/// carousel, recently added, cook tonight. Mirrors the design's V2HomeTracking.
struct HomeView: View {
    @Environment(AppState.self) private var app
    @State private var page: Int = 0
    @State private var selectedDayOffset: Int = 0
    @State private var openedRecipe: Recipe?

    private var cookable: [RecipeMatch] {
        Array(RecipeMatcher.rank(recipes: SeedData.recipes, fridge: app.fridge.items).prefix(3))
    }

    private var recent: [FoodItem] {
        Array(app.fridge.items.sorted { $0.addedAt > $1.addedAt }.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ambient wash gradient
                ZStack {
                    LinearGradient(
                        colors: [L.pop.opacity(0.10), .clear],
                        startPoint: .topTrailing, endPoint: .bottomLeading
                    )
                    .frame(height: 1)
                }
                .frame(height: 1)
                .padding(.top, -1)

                brandRow.padding(.top, 54).padding(.horizontal, L.S.pad)
                dayStrip.padding(.top, 18).padding(.horizontal, L.S.pad)

                StatCarousel(
                    page: $page,
                    fresh: app.fridge.freshCount,
                    total: app.fridge.total,
                    freshPct: app.fridge.freshPct,
                    today: app.fridge.todayCount,
                    soon: app.fridge.soonCount,
                    low: app.fridge.lowCount,
                    score: app.auth.profile?.fridgeScore ?? 8
                )
                .padding(.top, 24)

                recentlyAddedSection.padding(.top, 30)

                cookTonightSection.padding(.top, 30)

                Color.clear.frame(height: 130) // tab bar gap
            }
        }
        .background(L.paper.ignoresSafeArea())
        .background(
            RadialGradient(
                colors: [L.pop.opacity(0.10), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()
        )
        .sheet(item: $openedRecipe) { recipe in
            RecipeDetailView(recipe: recipe) { openedRecipe = nil }
        }
        .task {
            if let uid = app.auth.currentUserId, app.fridge.items.isEmpty {
                await app.fridge.reload(userId: uid)
            }
        }
    }

    // MARK: - Brand row

    private var brandRow: some View {
        HStack {
            HStack(spacing: 10) {
                FridgeMark()
                Text("Levla")
                    .font(.manrope(26, .heavy))
                    .kerning(-0.8)
                    .foregroundStyle(L.ink)
            }
            Spacer()
            StreakPill(days: app.auth.profile?.streakDays ?? 5)
        }
    }

    // MARK: - 7-day strip

    private var dayStrip: some View {
        // 7 days: -3..+3 around today
        let calendar = Calendar.current
        let base = Date()
        let labels = ["S","M","T","W","T","F","S"]
        return HStack(spacing: 2) {
            ForEach(-3...3, id: \.self) { offset in
                let d = calendar.date(byAdding: .day, value: offset, to: base) ?? base
                let dow = calendar.component(.weekday, from: d) - 1
                let day = calendar.component(.day, from: d)
                let badge = expiringCount(forDayOffset: offset)
                DayDot(
                    letter: labels[dow % 7],
                    num: day,
                    selected: offset == selectedDayOffset,
                    past: offset < 0,
                    future: offset > 3,
                    badge: offset >= 0 && offset <= 2 ? badge : 0
                ) {
                    selectedDayOffset = offset
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func expiringCount(forDayOffset offset: Int) -> Int {
        app.fridge.items.filter { $0.daysLeft == offset }.count
    }

    // MARK: - Recently added

    private var recentlyAddedSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Recently added")
                    .font(.manrope(24, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Spacer()
                Button { app.selectedTab = .fridge } label: {
                    Text("See all")
                        .font(.manrope(13.5, .heavy))
                        .foregroundStyle(L.ink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            InfoBanner(icon: "bell", text: "Scan a receipt to add up to 20 items in one go.")

            VStack(spacing: 12) {
                if recent.isEmpty {
                    EmptyRecentlyAdded()
                } else {
                    ForEach(recent) { item in
                        RecentCard(item: item)
                    }
                }
            }
        }
        .padding(.horizontal, L.S.pad)
    }

    // MARK: - Cook tonight

    private var cookTonightSection: some View {
        VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Cook tonight")
                    .font(.manrope(24, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Spacer()
                Button { app.selectedTab = .cook } label: {
                    Text("All")
                        .font(.manrope(13.5, .heavy))
                        .foregroundStyle(L.ink.opacity(0.5))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 14) {
                if cookable.isEmpty || app.fridge.items.isEmpty {
                    EmptyCookCard()
                } else {
                    ForEach(cookable) { m in
                        Button { openedRecipe = m.recipe } label: {
                            TrackRecipeCard(match: m)
                        }
                        .buttonStyle(.plain)
                        .tapPress()
                    }
                }
            }
        }
        .padding(.horizontal, L.S.pad)
    }
}

private struct EmptyCookCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Scan your fridge first.")
                .font(.manrope(16, .heavy))
                .foregroundStyle(L.ink)
            Text("Recipe suggestions appear based on what you actually have.")
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

// MARK: - Subcomponents

private struct FridgeMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(L.ink)
            VStack(spacing: 6) {
                Capsule().fill(L.cream.opacity(0.55)).frame(width: 2.5, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                Capsule().fill(L.cream.opacity(0.35)).frame(width: 22, height: 1.5)
                Capsule().fill(L.cream.opacity(0.55)).frame(width: 2.5, height: 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
            }
        }
        .frame(width: 34, height: 38)
        .shadow(color: L.ink.opacity(0.18), radius: 6, x: 0, y: 4)
    }
}

private struct StreakPill: View {
    let days: Int
    var body: some View {
        HStack(spacing: 7) {
            LSymbol(key: "leaf", size: 17, weight: .semibold).foregroundStyle(L.mint)
            Text("\(days)").font(.manrope(14.5, .heavy)).kerning(-0.2)
        }
        .foregroundStyle(L.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white, in: Capsule())
        .modifier(_HomeSoft())
    }
}

private struct DayDot: View {
    let letter: String
    let num: Int
    let selected: Bool
    let past: Bool
    let future: Bool
    let badge: Int
    let onTap: () -> Void

    private var labelColor: Color {
        if selected { return L.ink }
        if past { return L.ink.opacity(0.35) }
        if future { return L.ink.opacity(0.40) }
        return L.ink.opacity(0.55)
    }
    private var ringColor: Color {
        selected ? L.ink : L.ink.opacity(0.30)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: selected ? 1.8 : 1.3, lineCap: .round, dash: [4, 3]))
                        .foregroundStyle(ringColor)
                        .frame(width: 38, height: 38)
                    Text(letter)
                        .font(.manrope(14, selected ? .heavy : .bold))
                        .kerning(-0.2)
                        .foregroundStyle(labelColor)
                    if badge > 0 {
                        ZStack {
                            Circle().fill(L.pop)
                                .overlay(Circle().stroke(L.paper, lineWidth: 2))
                                .frame(width: 18, height: 18)
                            Text("\(badge)")
                                .font(.manrope(10.5, .heavy))
                                .foregroundStyle(L.cream)
                        }
                        .offset(x: 16, y: -16)
                    }
                }
                Text("\(num)")
                    .font(.manrope(14, selected ? .heavy : .semibold))
                    .kerning(-0.3)
                    .foregroundStyle(labelColor)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct _HomeSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

// MARK: - Stat carousel

private struct StatCarousel: View {
    @Binding var page: Int
    let fresh: Int
    let total: Int
    let freshPct: Double
    let today: Int
    let soon: Int
    let low: Int
    let score: Int

    var body: some View {
        VStack(spacing: 18) {
            TabView(selection: $page) {
                StatPage {
                    HeroCard(big: today, unit: "/ \(max(total, 1))", label: "items need using today", pct: total == 0 ? 0 : Double(today) / Double(total), icon: "leaf", tone: L.mint)
                }
                .tag(0)

                StatPage {
                    HStack(spacing: 10) {
                        MiniStat(big: today, label: "Expire today", icon: "flame", tone: .rose, pct: today == 0 ? 0 : 1)
                        MiniStat(big: soon, label: "This week", icon: "clock", tone: .pop, pct: min(1.0, Double(soon) / 6.0))
                        MiniStat(big: low, label: "Low stock", icon: "box", tone: .sun, pct: low > 0 ? 0.6 : 0)
                    }
                }
                .tag(1)

                StatPage {
                    ScoreCard(score: score)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 192)

            HStack(spacing: 7) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(i == page ? L.ink : L.ink.opacity(0.20))
                        .frame(width: i == page ? 9 : 7, height: i == page ? 9 : 7)
                        .animation(.easeInOut(duration: 0.18), value: page)
                }
            }
        }
    }
}

private struct StatPage<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(.horizontal, L.S.pad)
    }
}

private struct HeroCard: View {
    let big: Int
    let unit: String
    let label: String
    let pct: Double
    let icon: String
    let tone: Color

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(big)")
                        .font(.manrope(64, .heavy))
                        .kerning(-3)
                        .foregroundStyle(L.ink)
                    Text(unit)
                        .font(.manrope(18, .bold))
                        .kerning(-0.5)
                        .foregroundStyle(L.ink.opacity(0.4))
                }
                Text(label)
                    .font(.manrope(16, .bold))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 12)
            Dial(pct: pct, size: 124, stroke: 14, icon: icon, tone: tone)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 168)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

private struct MiniStat: View {
    enum Tone { case rose, pop, sun, mint }
    let big: Int
    let label: String
    let icon: String
    let tone: Tone
    let pct: Double

    private var color: Color {
        switch tone { case .rose: return L.rose; case .pop: return L.pop; case .sun: return L.sun; case .mint: return L.mint }
    }
    private var bg: Color {
        switch tone { case .rose: return L.roseBg; case .pop: return L.popBg; case .sun: return L.sunBg; case .mint: return L.mintBg }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(big)")
                .font(.manrope(32, .heavy))
                .kerning(-1.2)
                .foregroundStyle(L.ink)
            Text(label)
                .font(.manrope(12.5, .bold))
                .kerning(-0.2)
                .foregroundStyle(L.ink)
            Spacer()
            HStack {
                Spacer()
                Dial(pct: pct, size: 72, stroke: 8, icon: icon, tone: color, bg: bg, mini: true)
                Spacer()
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 168)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

private struct ScoreCard: View {
    let score: Int
    var body: some View {
        let pct = Double(score) / 10.0
        let barColor: Color = score >= 8 ? L.mint : (score >= 5 ? L.sun : L.rose)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text("Fridge Score")
                    .font(.manrope(22, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.ink)
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(score)").font(.manrope(26, .heavy)).kerning(-0.8).foregroundStyle(L.ink)
                    Text("/10").font(.manrope(16, .bold)).foregroundStyle(L.ink.opacity(0.35))
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(L.ink.opacity(0.06))
                    Capsule().fill(barColor).frame(width: g.size.width * pct)
                }
            }
            .frame(height: 8)
            Text("Well stocked, low waste. Two greens are turning — cook them in the next two days to keep your score perfect.")
                .font(.manrope(13.5, .medium))
                .lineSpacing(3)
                .foregroundStyle(L.ink.opacity(0.55))
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

private struct _HomeCardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

// MARK: - Recently added card

private struct RecentCard: View {
    let item: FoodItem

    private var expLabel: String {
        if item.daysLeft <= 0 { return "Use today" }
        if item.daysLeft == 1 { return "Eat tomorrow" }
        return "\(item.daysLeft) days fresh"
    }
    private var expColor: Color {
        if item.daysLeft <= 1 { return L.pop }
        if item.daysLeft <= 4 { return Color(hex: 0xA07215) }
        return L.mint
    }
    private var whenLabel: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: item.addedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                FoodTile(food: item.foodKey, size: 100, radius: 16)
                Text(item.source.rawValue.uppercased())
                    .font(.manrope(9.5, .heavy))
                    .tracking(0.4)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(L.cream.opacity(0.92), in: Capsule())
                    .foregroundStyle(L.ink)
                    .padding(8)
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text(item.name)
                        .font(.manrope(16, .heavy))
                        .kerning(-0.3)
                        .foregroundStyle(L.ink)
                        .lineLimit(1)
                    Spacer()
                    Text(whenLabel)
                        .font(.manrope(11, .bold))
                        .kerning(-0.1)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(L.ink.opacity(0.04), in: Capsule())
                        .foregroundStyle(L.ink.opacity(0.55))
                }

                HStack(spacing: 6) {
                    LSymbol(key: "box", size: 14, weight: .semibold)
                    Text(item.qty)
                }
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
                .padding(.top, 6)

                Spacer()

                HStack(spacing: 6) {
                    Circle().fill(expColor).frame(width: 6, height: 6)
                    Text(expLabel)
                        .font(.manrope(12, .heavy))
                        .kerning(-0.1)
                        .foregroundStyle(expColor)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(L.ink.opacity(0.04), in: Capsule())
            }
            .padding(.vertical, 4)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

private struct EmptyRecentlyAdded: View {
    @Environment(AppState.self) var app
    var body: some View {
        VStack(spacing: 10) {
            Text("Your fridge is empty.")
                .font(.manrope(16, .heavy))
                .foregroundStyle(L.ink)
            Text("Tap the orange button to scan it in.")
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

// MARK: - Tracker-style recipe card

struct TrackRecipeCard: View {
    let match: RecipeMatch
    private var recipe: Recipe { match.recipe }

    var body: some View {
        HStack(spacing: 12) {
            FoodOrb(foods: Array(recipe.uses.prefix(3)), color: recipe.color, accent: recipe.accent, height: 92, radius: 14)
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.manrope(16, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        LSymbol(key: "clock", size: 14, weight: .semibold)
                        Text("\(recipe.timeMinutes)m")
                    }
                    Text("·").foregroundStyle(L.ink.opacity(0.25))
                    HStack(spacing: 4) {
                        LSymbol(key: "flame", size: 14, weight: .semibold)
                        Text("\(recipe.kcal)")
                    }
                }
                .font(.manrope(13, .bold))
                .foregroundStyle(L.ink.opacity(0.6))

                if match.matchPct == 100 {
                    LPill(tone: .mint) {
                        LSymbol(key: "check", size: 13, weight: .heavy)
                        Text("All in your fridge")
                    }
                } else if !match.useSoonIngredients.isEmpty {
                    LPill(tone: .pop) {
                        LSymbol(key: "flame", size: 12, weight: .heavy)
                        Text("Uses \(match.useSoonIngredients.first?.name ?? "soon") today")
                    }
                } else {
                    LPill(tone: .neutral) {
                        Text("\(match.matchPct)% match · \(match.missingIngredients.count) to buy")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(_HomeCardShadow())
    }
}

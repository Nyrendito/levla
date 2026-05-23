import SwiftUI

/// Cook — Tinder-style swipe deck of recipes. Mirrors V2Recipes.
struct CookDeckView: View {
    @Environment(AppState.self) private var app

    private let moods = ["Tonight", "Quick", "Veggie", "Comfort", "High-protein"]
    @State private var mood = "Tonight"
    @State private var idx = 0
    @State private var saved = 0
    @State private var openedRecipe: Recipe?
    @State private var dragOffset: CGSize = .zero
    @State private var animating = false

    private var source: [RecipeMatch] {
        RecipeMatcher.rank(recipes: app.recipes.recipes, fridge: app.fridge.items)
    }

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 50)
                pipCounter
                    .padding(.top, 8)

                ZStack {
                    if app.fridge.items.isEmpty {
                        EmptyFridgeForCookView()
                    } else if idx >= source.count {
                        DeckDoneView(total: source.count, saved: saved) {
                            saved = 0; idx = 0
                        }
                    } else {
                        deckStack
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if idx < source.count {
                    actionRow
                        .padding(.horizontal, L.S.pad)
                        .padding(.bottom, 102)
                }
            }
        }
        .sheet(item: $openedRecipe) { r in
            RecipeDetailView(recipe: r) { openedRecipe = nil }
        }
        .task {
            await app.recipes.reload(for: app.fridge.items)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(moods, id: \.self) { m in
                        Button { withAnimation { mood = m } } label: {
                            Text(m)
                                .font(.manrope(13, .bold))
                                .kerning(-0.1)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(mood == m ? L.ink : L.cream.opacity(0.92), in: Capsule())
                                .foregroundStyle(mood == m ? L.cream : L.ink)
                                .shadow(color: L.ink.opacity(mood == m ? 0.18 : 0.08), radius: mood == m ? 8 : 3, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            BigIconBtn(icon: "filter") {}
        }
    }

    private var pipCounter: some View {
        HStack(spacing: 4) {
            ForEach(0..<source.count, id: \.self) { i in
                Capsule()
                    .fill(i < idx ? L.ink.opacity(0.22) : (i == idx ? L.ink : L.ink.opacity(0.10)))
                    .frame(width: i == idx ? 16 : 5, height: 5)
            }
        }
    }

    // MARK: - Deck

    private var deckStack: some View {
        GeometryReader { _ in
            ZStack {
                if idx + 2 < source.count {
                    cardView(source[idx + 2])
                        .scaleEffect(0.92)
                        .offset(y: 20)
                        .opacity(0.55)
                        .allowsHitTesting(false)
                }
                if idx + 1 < source.count {
                    cardView(source[idx + 1])
                        .scaleEffect(0.96)
                        .offset(y: 10)
                        .opacity(0.85)
                        .allowsHitTesting(false)
                }
                topCard
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var topCard: some View {
        let match = source[idx]
        cardView(match)
            .offset(dragOffset)
            .rotationEffect(.degrees(Double(dragOffset.width / 18)))
            .gesture(
                DragGesture()
                    .onChanged { v in
                        if !animating { dragOffset = v.translation }
                    }
                    .onEnded { v in
                        if v.translation.height < -110 { commit(.up) }
                        else if v.translation.width > 90 { commit(.yes) }
                        else if v.translation.width < -90 { commit(.no) }
                        else {
                            withAnimation(.spring()) { dragOffset = .zero }
                        }
                    }
            )
            .onTapGesture { openedRecipe = match.recipe }
    }

    private func cardView(_ m: RecipeMatch) -> some View {
        SwipeCard(match: m,
                  dragX: dragOffset.width, dragY: dragOffset.height)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 18) {
            ActionBtn(icon: "undo", size: 48, bg: L.cream.opacity(0.92), fg: L.ink.opacity(0.55)) { undo() }
            ActionBtn(icon: "close", size: 64, bg: .white, fg: L.pop, big: true) { commit(.no) }
            ActionBtn(icon: "flame", size: 72, bg: L.ink, fg: L.cream, big: true) { commit(.up) }
            ActionBtn(icon: "heart", size: 64, bg: .white, fg: L.mint, big: true) { commit(.yes) }
            ActionBtn(icon: "arrowR", size: 48, bg: L.cream.opacity(0.92), fg: L.ink.opacity(0.55)) {
                if idx < source.count { openedRecipe = source[idx].recipe }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private enum SwipeDirection { case yes, no, up }

    private func commit(_ direction: SwipeDirection) {
        guard !animating else { return }
        animating = true
        let dx: CGFloat = direction == .yes ? 600 : direction == .no ? -600 : 0
        let dy: CGFloat = direction == .up ? -800 : 0
        withAnimation(.easeOut(duration: 0.32)) { dragOffset = .init(width: dx, height: dy) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            if direction == .up, idx < source.count { openedRecipe = source[idx].recipe }
            if direction == .yes { saved += 1 }
            idx += 1
            dragOffset = .zero
            animating = false
        }
    }

    private func undo() {
        guard !animating, idx > 0 else { return }
        idx -= 1
    }
}

// MARK: - SwipeCard

private struct SwipeCard: View {
    let match: RecipeMatch
    var dragX: CGFloat = 0
    var dragY: CGFloat = 0

    private var recipe: Recipe { match.recipe }

    private var yesOpacity: Double { Double(min(1, max(0, dragX / 80))) }
    private var noOpacity:  Double { Double(min(1, max(0, -dragX / 80))) }
    private var upOpacity:  Double { Double(min(1, max(0, -dragY / 80))) }

    var body: some View {
        ZStack {
            FoodOrb(foods: recipe.uses, color: recipe.color, accent: recipe.accent, height: 1000, radius: L.R.xxl)
            LinearGradient(
                colors: [.clear, Color(hex: 0x140F0A).opacity(0.30), Color(hex: 0x140F0A).opacity(0.78)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack {
                HStack {
                    if match.matchPct == 100 {
                        HStack(spacing: 6) {
                            LSymbol(key: "check", size: 13, weight: .heavy)
                            Text("All in fridge")
                        }
                        .font(.manrope(13, .heavy))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(L.mint, in: Capsule())
                        .foregroundStyle(L.cream)
                        .shadow(color: L.mint.opacity(0.32), radius: 8, x: 0, y: 4)
                    } else {
                        Text("\(match.matchPct)% match")
                            .font(.manrope(13, .heavy))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(L.pop, in: Capsule())
                            .foregroundStyle(L.cream)
                            .shadow(color: L.pop.opacity(0.32), radius: 8, x: 0, y: 4)
                    }
                    Spacer()
                    HStack(spacing: 5) {
                        LSymbol(key: "clock", size: 13, weight: .heavy)
                        Text("\(recipe.timeMinutes)m")
                    }
                    .font(.manrope(12.5, .heavy))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(L.cream.opacity(0.85), in: Capsule())
                    .foregroundStyle(L.ink)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        ForEach(recipe.tags.prefix(3), id: \.self) { t in
                            Text(t)
                                .font(.manrope(11, .bold))
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(L.cream.opacity(0.18), in: Capsule())
                                .foregroundStyle(L.cream)
                        }
                    }
                    Text(recipe.title)
                        .font(.manrope(30, .heavy))
                        .kerning(-1)
                        .foregroundStyle(L.cream)
                        .lineLimit(2)
                    Text(recipe.subtitle)
                        .font(.manrope(14, .medium))
                        .foregroundStyle(L.cream.opacity(0.78))

                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            LSymbol(key: "flame", size: 14, weight: .semibold)
                            Text("\(recipe.kcal) kcal")
                        }
                        Text("\(recipe.protein)g protein")
                        if !match.missingIngredients.isEmpty {
                            HStack(spacing: 5) {
                                LSymbol(key: "cart", size: 13, weight: .semibold)
                                Text("\(match.missingIngredients.count) to buy")
                            }
                            .foregroundStyle(L.pop)
                        }
                    }
                    .font(.manrope(13, .bold))
                    .foregroundStyle(L.cream.opacity(0.88))
                    HStack(spacing: 4) {
                        Text("Tap for recipe")
                        LSymbol(key: "arrowR", size: 12, weight: .heavy)
                    }
                    .font(.manrope(12, .bold))
                    .foregroundStyle(L.cream.opacity(0.7))
                }
                .padding(22)
            }

            stamp("SKIP", color: L.pop, rotate: -12, opacity: noOpacity, alignment: .topLeading, offset: .init(width: 24, height: 36))
            stamp("SAVE", color: L.mint, rotate: 12, opacity: yesOpacity, alignment: .topTrailing, offset: .init(width: -24, height: 36))
            stamp("COOK NOW", color: L.ink, rotate: 0, opacity: upOpacity, alignment: .top, offset: .init(width: 0, height: 36), bg: L.cream.opacity(0.85))
        }
        .clipShape(RoundedRectangle(cornerRadius: L.R.xxl, style: .continuous))
        .shadow(color: L.ink.opacity(0.18), radius: 30, x: 0, y: 14)
    }

    private func stamp(_ text: String, color: Color, rotate: Double, opacity: Double, alignment: Alignment, offset: CGSize, bg: Color = .clear) -> some View {
        Text(text)
            .font(.manrope(32, .heavy))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color, lineWidth: 4))
            .rotationEffect(.degrees(rotate))
            .opacity(opacity)
            .offset(offset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .allowsHitTesting(false)
    }
}

// MARK: - DeckDone

private struct DeckDoneView: View {
    let total: Int
    let saved: Int
    let onRestart: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(L.mintBg)
                LSymbol(key: "check", size: 36, weight: .heavy).foregroundStyle(L.mint)
            }
            .frame(width: 78, height: 78)

            Text("That's all for tonight.")
                .font(.manrope(26, .heavy))
                .kerning(-0.8)
                .foregroundStyle(L.ink)
                .multilineTextAlignment(.center)
            Text("You saved \(saved) of \(total) ideas. Fresh picks reload tomorrow at 6am.")
                .font(.manrope(14, .medium))
                .lineSpacing(3)
                .foregroundStyle(L.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Button(action: onRestart) {
                HStack(spacing: 6) {
                    LSymbol(key: "undo", size: 15, weight: .heavy)
                    Text("Restart deck")
                }
                .font(.manrope(14, .heavy))
                .padding(.horizontal, 22).padding(.vertical, 12)
                .background(L.ink, in: Capsule())
                .foregroundStyle(L.cream)
                .shadow(color: L.ink.opacity(0.22), radius: 14, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xxl, style: .continuous))
        .shadow(color: L.ink.opacity(0.10), radius: 30, x: 0, y: 14)
    }
}

private struct EmptyFridgeForCookView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(L.popBg)
                LSymbol(key: "fridge", size: 36, weight: .heavy).foregroundStyle(L.pop)
            }
            .frame(width: 78, height: 78)

            Text("Scan your fridge first.")
                .font(.manrope(26, .heavy))
                .kerning(-0.8)
                .foregroundStyle(L.ink)
                .multilineTextAlignment(.center)
            Text("Levla matches recipes against what you actually have. Open the orange Scan button below.")
                .font(.manrope(14, .medium))
                .lineSpacing(3)
                .foregroundStyle(L.ink.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xxl, style: .continuous))
        .shadow(color: L.ink.opacity(0.10), radius: 30, x: 0, y: 14)
    }
}

// MARK: - Action button

struct ActionBtn: View {
    let icon: String
    var size: CGFloat = 56
    let bg: Color
    let fg: Color
    var big: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle().fill(bg)
                LSymbol(key: icon, size: big ? 26 : 20, weight: .heavy).foregroundStyle(fg)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .shadow(color: L.ink.opacity(big ? 0.18 : 0.10), radius: big ? 14 : 8, x: 0, y: big ? 8 : 4)
        .tapPress()
    }
}

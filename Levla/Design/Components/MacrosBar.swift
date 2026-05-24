import SwiftUI

/// Three-page macros carousel on Home, Cal-AI inspired:
///
/// Page 1 — Calories hero card with arc ring + flame, then 3 macro cards
///          (Protein / Carbs / Fat) showing GRAMS LEFT against the user's
///          personalized goal with a small filled-ring of progress.
/// Page 2 — Fiber / Sugar / Sodium cards (same gram-left + ring pattern),
///          stacked above a Health Score panel with a 0-10 score and an
///          AI-style commentary line.
/// Page 3 — Steps (Apple Health placeholder) + Calories burned + Water
///          (manual +/− tracker that auto-resets at midnight).
///
/// Driver state is held by the parent (HomeView) — this view is purely
/// presentational. All numbers come from the Profile + CookedLogService.
struct MacrosCarousel: View {
    // Eaten today
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let fiber: Int
    let sugar: Int
    let sodium: Int
    let hasLogs: Bool

    // Personalized targets
    var kcalGoal: Int? = nil
    var proteinGoal: Int? = nil
    var carbsGoal: Int? = nil
    var fatGoal: Int? = nil
    var fiberGoal: Int? = nil
    var sugarGoal: Int? = nil
    var sodiumGoal: Int? = nil

    // Page 3 inputs (Apple Health + manual water)
    var stepsToday: Int = 0
    var stepsGoal: Int = 10_000
    var caloriesBurned: Int = 0
    var waterMl: Int = 0
    var waterGoalMl: Int = 2_000
    var onWaterPlus:  () -> Void = {}
    var onWaterMinus: () -> Void = {}
    var onConnectHealth: () -> Void = {}

    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                page1.tag(0)
                page2.tag(1)
                page3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i == page ? L.ink : L.ink.opacity(0.18))
                        .frame(width: i == page ? 7 : 5, height: i == page ? 7 : 5)
                        .animation(.easeInOut(duration: 0.18), value: page)
                }
            }
        }
    }

    // MARK: - Page 1: Calories hero + macros

    private var page1: some View {
        VStack(spacing: 12) {
            CaloriesHeroCard(kcal: kcal, goal: kcalGoal)

            HStack(spacing: 10) {
                MicroCard(label: "Protein", value: protein, goal: proteinGoal,
                          unit: "g", color: L.macroProtein, icon: "drumstick.fill", iconAsset: "🍗")
                MicroCard(label: "Carbs",   value: carbs,   goal: carbsGoal,
                          unit: "g", color: L.macroCarbs, icon: "leaf.fill", iconAsset: "🌾")
                MicroCard(label: "Fat",     value: fat,     goal: fatGoal,
                          unit: "g", color: L.macroFat, icon: "drop.fill", iconAsset: "🥑")
            }
        }
    }

    // MARK: - Page 2: Fiber / Sugar / Sodium + Health Score

    private var page2: some View {
        let score = HealthScore.compute(
            kcal: kcal, kcalGoal: kcalGoal,
            protein: protein, proteinGoal: proteinGoal,
            carbs: carbs, carbsGoal: carbsGoal,
            fat: fat, fatGoal: fatGoal,
            fiber: fiber, fiberGoal: fiberGoal,
            sugar: sugar, sugarGoal: sugarGoal,
            sodium: sodium, sodiumGoal: sodiumGoal,
            hasLogs: hasLogs
        )
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                MicroCard(label: "Fiber",  value: fiber,  goal: fiberGoal,
                          unit: "g",  color: Color(hex: 0x9A6FCE), icon: "leaf.fill", iconAsset: "🫐")
                MicroCard(label: "Sugar",  value: sugar,  goal: sugarGoal,
                          unit: "g",  color: Color(hex: 0xE0789B), icon: "drop.fill", iconAsset: "🍭",
                          lessIsBetter: true)
                MicroCard(label: "Sodium", value: sodium, goal: sodiumGoal,
                          unit: "mg", color: Color(hex: 0xD49B3E), icon: "drop.fill", iconAsset: "🧂",
                          lessIsBetter: true)
            }
            HealthScoreCard(score: score)
        }
    }

    // MARK: - Page 3: Steps + Calories burned + Water

    private var page3: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                StepsCard(steps: stepsToday, goal: stepsGoal, onConnect: onConnectHealth)
                CaloriesBurnedCard(burned: caloriesBurned, onConnect: onConnectHealth)
            }
            WaterCard(ml: waterMl, goal: waterGoalMl, onPlus: onWaterPlus, onMinus: onWaterMinus)
        }
    }
}

// MARK: - Cal-AI calories hero (big card)

/// Big top card: "1505 / Calories left" on the left, large arc ring with
/// flame icon on the right. Mirrors the Cal AI Page 1 hero.
private struct CaloriesHeroCard: View {
    let kcal: Int
    let goal: Int?

    private var progress: Double {
        guard let g = goal, g > 0 else { return 0 }
        return max(0, min(1, Double(kcal) / Double(g)))
    }
    private var left: Int { max(0, (goal ?? 0) - kcal) }
    private var over: Int { max(0, kcal - (goal ?? 0)) }
    private var hasGoal: Bool { (goal ?? 0) > 0 }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(headline)")
                    .font(.manrope(46, .heavy))
                    .kerning(-1.4)
                    .foregroundStyle(L.ink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: headline)
                Text(headlineLabel)
                    .font(.manrope(13.5, .heavy))
                    .foregroundStyle(over > 0 ? L.pop : L.muted)
                    .tracking(0.2)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(L.ink.opacity(0.06), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(L.ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                ZStack {
                    Circle().fill(L.ink.opacity(0.05))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(L.ink)
                }
                .frame(width: 56, height: 56)
            }
            .frame(width: 120, height: 120)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }

    private var headline: Int {
        if !hasGoal { return kcal }
        if over > 0 { return over }
        return left
    }
    private var headlineLabel: String {
        if !hasGoal { return "Calories eaten" }
        if over > 0 { return "Calories over" }
        return "Calories left"
    }
}

// MARK: - Micro card (Protein/Carbs/Fat/Fiber/Sugar/Sodium)

/// Small white card: "<value>g / Label left", with a circular ring at the
/// bottom showing progress. Mirrors Cal AI's "129g / Protein left" tile.
/// `lessIsBetter` flips the ring fill direction (we fill MORE as you get
/// CLOSER to the goal, but we still cap visually at 1.0; commentary in
/// HealthScore handles over-target penalties).
private struct MicroCard: View {
    let label: String
    let value: Int
    let goal: Int?
    let unit: String
    let color: Color
    let icon: String       // SF Symbol
    let iconAsset: String  // Fallback emoji (used if SF Symbol unavailable)
    var lessIsBetter: Bool = false

    private var left: Int { max(0, (goal ?? 0) - value) }
    private var progress: Double {
        guard let g = goal, g > 0 else { return 0 }
        return max(0, min(1, Double(value) / Double(g)))
    }
    private var hasGoal: Bool { (goal ?? 0) > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(hasGoal ? left : value)\(unit)")
                    .font(.manrope(22, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.ink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: left)
                HStack(spacing: 4) {
                    Text(label)
                        .font(.manrope(12, .heavy))
                        .foregroundStyle(L.ink)
                    Text(hasGoal ? "left" : "today")
                        .font(.manrope(12, .semibold))
                        .foregroundStyle(L.muted)
                }
            }

            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(L.ink.opacity(0.06), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 54, height: 54)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }
}

// MARK: - Health Score card

private struct HealthScoreCard: View {
    let score: HealthScore?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Health Score")
                    .font(.manrope(17, .heavy))
                    .foregroundStyle(L.ink)
                Spacer()
                Text(score.map { "\($0.score)/10" } ?? "N/A")
                    .font(.manrope(15, .heavy))
                    .foregroundStyle(score == nil ? L.muted : barColor)
            }

            // Progress bar
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(L.ink.opacity(0.06))
                    if let score {
                        Capsule()
                            .fill(barColor)
                            .frame(width: proxy.size.width * CGFloat(score.score) / 10)
                    }
                }
            }
            .frame(height: 6)

            Text(score?.commentary ?? "Track a few meals to generate your health score for today. It reflects how well you're meeting your macro and micro targets.")
                .font(.manrope(12.5, .semibold))
                .foregroundStyle(L.ink.opacity(0.6))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }

    private var barColor: Color {
        guard let s = score?.score else { return L.muted }
        if s >= 8 { return L.brand }
        if s >= 5 { return L.sun }
        return L.pop
    }
}

// MARK: - Page 3 cards (Steps / Calories burned / Water)

private struct StepsCard: View {
    let steps: Int
    let goal: Int
    let onConnect: () -> Void

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return max(0, min(1, Double(steps) / Double(goal)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(steps)")
                        .font(.manrope(22, .heavy))
                        .kerning(-0.6)
                        .foregroundStyle(L.ink)
                    Text("/ \(goal)")
                        .font(.manrope(12, .heavy))
                        .foregroundStyle(L.muted)
                }
                Text("Steps today")
                    .font(.manrope(12, .heavy))
                    .foregroundStyle(L.ink)
            }

            Spacer(minLength: 0)

            ZStack {
                Circle().stroke(L.ink.opacity(0.06), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(L.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(L.ink)
            }
            .frame(width: 54, height: 54)
            .frame(maxWidth: .infinity, alignment: .center)

            if steps == 0 {
                Button(action: onConnect) {
                    Text("Connect Apple Health")
                        .font(.manrope(11, .heavy))
                        .foregroundStyle(L.brand)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(L.brandBg, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }
}

private struct CaloriesBurnedCard: View {
    let burned: Int
    let onConnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(L.pop)
                Text("\(burned)")
                    .font(.manrope(22, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.ink)
            }
            Text("Calories burned")
                .font(.manrope(12, .heavy))
                .foregroundStyle(L.ink)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(L.ink)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Activity")
                        .font(.manrope(11, .heavy))
                        .foregroundStyle(L.muted)
                    Text("+\(burned)")
                        .font(.manrope(13, .heavy))
                        .foregroundStyle(L.ink)
                }
                Spacer()
            }

            if burned == 0 {
                Button(action: onConnect) {
                    Text("Connect Apple Health")
                        .font(.manrope(11, .heavy))
                        .foregroundStyle(L.brand)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(L.brandBg, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }
}

private struct WaterCard: View {
    let ml: Int
    let goal: Int
    let onPlus: () -> Void
    let onMinus: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: 0xCFE4F2))
                Image(systemName: "drop.fill")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x4E8CC2))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 0) {
                Text("Water")
                    .font(.manrope(15.5, .heavy))
                    .foregroundStyle(L.ink)
                HStack(spacing: 4) {
                    Text("\(ml) ml")
                        .font(.manrope(13, .heavy))
                        .foregroundStyle(L.ink)
                    Text("/ \(goal) ml")
                        .font(.manrope(12, .semibold))
                        .foregroundStyle(L.muted)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onMinus) {
                    ZStack {
                        Circle().strokeBorder(L.ink.opacity(0.12), lineWidth: 1)
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(L.ink)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Button(action: onPlus) {
                    ZStack {
                        Circle().fill(L.ink)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }
}

private struct _MacrosShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

// MARK: - Back-compat alias

/// Older call sites referenced `MacrosBar`. Keep the alias so any leftover
/// import builds; HomeView now uses `MacrosCarousel` directly.
typealias MacrosBar = MacrosCarousel

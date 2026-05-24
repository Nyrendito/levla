import SwiftUI

/// Cal-AI / Lifesum style daily macros card backed by personalized goals.
///
/// Left side: a big kcal ring that tracks "eaten today" against the user's
/// Mifflin-St Jeor + activity + goal-adjusted daily target. The headline
/// number switches to "calories left" so the user sees how much more they
/// can still eat (or, if they're over, a small "over by X" badge appears).
///
/// Right side: three macro dials (Protein / Carbs / Fat) showing grams
/// eaten vs. the personalized gram target for each. Rings fill to 100%
/// when the user hits their goal; the percentage in the centre is
/// "eaten ÷ goal" rather than the macro-share-of-energy ratio the older
/// version displayed (which always summed to 100% no matter how much you'd
/// actually eaten — confusing).
///
/// When no goals are supplied (rare — e.g. a brand-new profile that hasn't
/// finished onboarding), the dials fall back to the energy-share view
/// they had before so the card never looks empty.
struct MacrosBar: View {
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    /// Personalized targets from the user's Profile. nil → fall back to
    /// energy-share rings (legacy behaviour).
    var kcalGoal: Int? = nil
    var proteinGoal: Int? = nil
    var carbsGoal: Int? = nil
    var fatGoal: Int? = nil

    // MARK: - Derived

    private var totalEnergy: Double {
        let c = Double(carbs) * 4
        let f = Double(fat) * 9
        let p = Double(protein) * 4
        return max(1, c + f + p)
    }

    /// Progress ring fraction for the kcal ring. Always 0…1 — overshoot
    /// is communicated via the "over by" badge, not by stretching the ring.
    private var kcalProgress: Double {
        guard let goal = kcalGoal, goal > 0 else { return 0 }
        return max(0, min(1, Double(kcal) / Double(goal)))
    }

    private var kcalLeft: Int { max(0, (kcalGoal ?? 0) - kcal) }
    private var kcalOver: Int { max(0, kcal - (kcalGoal ?? 0)) }
    private var hasKcalGoal: Bool { (kcalGoal ?? 0) > 0 }

    /// For each macro: progress against its gram goal (with goals) or
    /// share-of-energy (fallback). Always 0…1.
    private func progress(grams: Int, goal: Int?, kcalPerGram: Double) -> Double {
        if let g = goal, g > 0 {
            return max(0, min(1, Double(grams) / Double(g)))
        }
        return (Double(grams) * kcalPerGram) / totalEnergy
    }

    private var proteinProgress: Double { progress(grams: protein, goal: proteinGoal, kcalPerGram: 4) }
    private var carbsProgress:   Double { progress(grams: carbs,   goal: carbsGoal,   kcalPerGram: 4) }
    private var fatProgress:     Double { progress(grams: fat,     goal: fatGoal,     kcalPerGram: 9) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                kcalBlock
                Spacer(minLength: 4)
                HStack(spacing: 12) {
                    DialDot(
                        label: "Protein", progress: proteinProgress,
                        color: L.macroProtein,
                        valueLabel: gramsLabel(protein, goal: proteinGoal)
                    )
                    DialDot(
                        label: "Carbs", progress: carbsProgress,
                        color: L.macroCarbs,
                        valueLabel: gramsLabel(carbs, goal: carbsGoal)
                    )
                    DialDot(
                        label: "Fat", progress: fatProgress,
                        color: L.macroFat,
                        valueLabel: gramsLabel(fat, goal: fatGoal)
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_MacrosShadow())
    }

    // MARK: - Kcal hero (ring + big number + tiny label)

    @ViewBuilder
    private var kcalBlock: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(L.inset, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(kcalProgress))
                    .stroke(L.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: kcalProgress)
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(L.brand)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(headlineKcal)")
                        .font(.manrope(28, .heavy))
                        .kerning(-0.7)
                        .foregroundStyle(L.ink)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: headlineKcal)
                    Text("kcal")
                        .font(.manrope(13, .heavy))
                        .foregroundStyle(L.muted)
                }
                Text(headlineSubtitle)
                    .font(.manrope(10, .heavy))
                    .tracking(1.2)
                    .foregroundStyle(headlineTint)
            }
        }
    }

    /// Big number on the left. With a goal: "calories left". Without a
    /// goal: just "eaten today". When the user has gone over: shows the
    /// surplus.
    private var headlineKcal: Int {
        if !hasKcalGoal { return kcal }
        if kcalOver > 0 { return kcalOver }
        return kcalLeft
    }

    private var headlineSubtitle: String {
        if !hasKcalGoal { return "EATEN TODAY" }
        if kcalOver > 0 { return "OVER BY · GOAL \(kcalGoal!)" }
        return "LEFT · GOAL \(kcalGoal!)"
    }

    private var headlineTint: Color {
        kcalOver > 0 ? L.pop : L.muted
    }

    // MARK: - Gram label helpers

    private func gramsLabel(_ value: Int, goal: Int?) -> String {
        if let g = goal, g > 0 { return "\(value) / \(g)g" }
        return "\(value)g"
    }
}

/// Small ring + label + grams/grams-of-goal text. Used for protein/carbs/fat.
private struct DialDot: View {
    let label: String
    let progress: Double
    let color: Color
    let valueLabel: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(L.inset, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.manrope(10.5, .heavy))
                    .foregroundStyle(L.ink)
            }
            .frame(width: 42, height: 42)
            Text(label)
                .font(.manrope(10, .heavy))
                .tracking(0.4)
                .foregroundStyle(L.muted)
            Text(valueLabel)
                .font(.manrope(10.5, .heavy))
                .foregroundStyle(L.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct _MacrosShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

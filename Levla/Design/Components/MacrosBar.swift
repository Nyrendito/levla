import SwiftUI

/// Lifesum-style daily macros card:
/// big kcal number on the left, three small circular ring dials on the right
/// (carbs / fat / protein) showing the percentage of today's calories from
/// each macro. Plus a small grams label under each ring.
struct MacrosBar: View {
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    private var totalEnergy: Double {
        // 4-9-4 calorie density approximation.
        let c = Double(carbs) * 4
        let f = Double(fat) * 9
        let p = Double(protein) * 4
        return max(1, c + f + p)
    }
    private var carbsPct:   Double { (Double(carbs) * 4) / totalEnergy }
    private var fatPct:     Double { (Double(fat) * 9) / totalEnergy }
    private var proteinPct: Double { (Double(protein) * 4) / totalEnergy }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(kcal)")
                            .font(.manrope(38, .heavy))
                            .kerning(-1)
                            .foregroundStyle(L.ink)
                        Text("kcal")
                            .font(.manrope(15, .heavy))
                            .foregroundStyle(L.muted)
                    }
                    Text("EATEN TODAY")
                        .font(.manrope(10.5, .heavy))
                        .tracking(1.4)
                        .foregroundStyle(L.muted)
                }
                Spacer()
                HStack(spacing: 12) {
                    DialDot(label: "Carbs",   percent: carbsPct,   color: L.macroCarbs,   grams: carbs)
                    DialDot(label: "Fat",     percent: fatPct,     color: L.macroFat,     grams: fat)
                    DialDot(label: "Protein", percent: proteinPct, color: L.macroProtein, grams: protein)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .modifier(_MacrosShadow())
    }
}

/// Small ring + percent + label + grams — Lifesum's signature macro pip.
private struct DialDot: View {
    let label: String
    let percent: Double
    let color: Color
    let grams: Int

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(L.inset, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(1, percent))))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((percent * 100).rounded()))%")
                    .font(.manrope(11, .heavy))
                    .foregroundStyle(L.ink)
            }
            .frame(width: 42, height: 42)
            Text(label)
                .font(.manrope(10, .heavy))
                .tracking(0.4)
                .foregroundStyle(L.muted)
            Text("\(grams)g")
                .font(.manrope(11, .heavy))
                .foregroundStyle(L.ink)
        }
    }
}

private struct _MacrosShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

import SwiftUI

/// Today's macros card — Cal-AI / BitePal pattern:
/// big kcal number + horizontal stacked bar (carbs / fat / protein) +
/// macro values below as dot + label + grams.
///
/// Empty state collapses to a friendly invitation to cook something.
struct MacrosBar: View {
    let kcal: Int
    let protein: Int
    let carbs: Int
    let fat: Int

    /// Cal-AI brand-ish accents:
    /// - carbs = yellow (calories per gram from carbs are highest by mass)
    /// - fat = blue
    /// - protein = green
    private let carbsColor   = Color(hex: 0xE4B33A)   // warm yellow
    private let fatColor     = Color(hex: 0x4A8CE4)   // deep blue
    private let proteinColor = Color(hex: 0x4DA66B)   // green

    private var caloriesByMacro: (carbs: Double, fat: Double, protein: Double) {
        // Approximate: 4 kcal/g carbs, 9 kcal/g fat, 4 kcal/g protein.
        // The bar visualizes the energy contribution, not raw grams.
        (Double(carbs) * 4, Double(fat) * 9, Double(protein) * 4)
    }

    private var totalEnergy: Double {
        let c = caloriesByMacro
        return max(1, c.carbs + c.fat + c.protein)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(kcal)")
                    .font(.manrope(38, .heavy))
                    .kerning(-1.4)
                    .foregroundStyle(L.ink)
                Text("kcal today")
                    .font(.manrope(15, .heavy))
                    .foregroundStyle(L.ink.opacity(0.45))
            }

            stackedBar
                .frame(height: 8)

            HStack(alignment: .firstTextBaseline) {
                macroLabel(color: carbsColor,   label: "Carbs",   grams: carbs)
                Spacer()
                macroLabel(color: fatColor,     label: "Fat",     grams: fat)
                Spacer()
                macroLabel(color: proteinColor, label: "Protein", grams: protein)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_MacrosShadow())
    }

    // MARK: - Stacked bar

    private var stackedBar: some View {
        GeometryReader { proxy in
            let total = totalEnergy
            let e = caloriesByMacro
            let widths = (
                carbs:   proxy.size.width * e.carbs   / total,
                fat:     proxy.size.width * e.fat     / total,
                protein: proxy.size.width * e.protein / total
            )

            if kcal == 0 {
                Capsule().fill(L.ink.opacity(0.08))
            } else {
                HStack(spacing: 3) {
                    Capsule().fill(carbsColor).frame(width: max(0, widths.carbs))
                    Capsule().fill(fatColor).frame(width: max(0, widths.fat))
                    Capsule().fill(proteinColor).frame(width: max(0, widths.protein))
                }
            }
        }
    }

    // MARK: - Macro label

    private func macroLabel(color: Color, label: String, grams: Int) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.manrope(11.5, .heavy))
                    .kerning(0.3)
                    .foregroundStyle(L.ink.opacity(0.55))
                Text("\(grams)g")
                    .font(.manrope(16, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
            }
        }
    }
}

private struct _MacrosShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

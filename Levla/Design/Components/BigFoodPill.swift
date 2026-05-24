import SwiftUI

/// Big food list row — food tile + name + qty. Optional "low" tag on the
/// right (only thing we can reliably tell from a fridge photo — half-empty
/// jars are visible; expiry dates aren't).
struct BigFoodPill: View {
    let food: String
    let name: String
    let qty: String
    let status: FreshnessStatus
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(L.inset)
                    FoodTile(food: food, size: 42, radius: 14)
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.manrope(16, .semibold))
                        .kerning(-0.3)
                        .foregroundStyle(L.ink)
                        .lineLimit(1)
                    Text(qty)
                        .font(.manrope(13, .semibold))
                        .foregroundStyle(L.ink.opacity(0.55))
                }

                Spacer(minLength: 8)

                if status == .low {
                    Text("low")
                        .font(.manrope(12, .heavy))
                        .kerning(-0.1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(L.sun, in: Capsule())
                        .foregroundStyle(L.cream)
                }
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_CardShadow())
        .tapPress()
    }
}

private struct _CardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}


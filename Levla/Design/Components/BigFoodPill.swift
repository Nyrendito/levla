import SwiftUI

/// Big food list row — 64pt-tall pill with food tile + name + qty + status pill.
struct BigFoodPill: View {
    let food: String
    let name: String
    let qty: String
    let status: FreshnessStatus
    let days: Int
    var onTap: () -> Void = {}

    private var tones: (bg: Color, ring: Color) {
        switch status {
        case .today: return (L.roseBg, L.rose)
        case .soon:  return (L.popBg, L.pop)
        case .fresh: return (L.mintBg, L.mint)
        case .low:   return (L.sunBg, L.sun)
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(tones.bg)
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

                Text(statusLabel(status: status, days: days))
                    .font(.manrope(12, .heavy))
                    .kerning(-0.1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(tones.ring, in: Capsule())
                    .foregroundStyle(L.cream)
            }
            .padding(10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_CardShadow())
        .tapPress()
    }
}

func statusLabel(status: FreshnessStatus, days: Int) -> String {
    switch status {
    case .today: return "today"
    case .soon:  return "\(days)d left"
    case .fresh: return days <= 30 ? "\(days)d" : "fresh"
    case .low:   return "low"
    }
}

private struct _CardShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

/// Status freshness tile (count + label) used on Fridge screen.
struct StatusTile: View {
    let count: Int
    let label: String
    let tone: FreshnessStatus

    private var t: (bg: Color, fg: Color, dot: Color) {
        switch tone {
        case .today: return (L.roseBg, L.rose, L.rose)
        case .soon:  return (L.popBg, L.pop, L.pop)
        case .fresh: return (L.mintBg, L.mint, L.mint)
        case .low:   return (L.sunBg, L.sunFg, L.sun)
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(t.bg)
            Circle().fill(t.dot).frame(width: 8, height: 8).padding(.leading, 14).padding(.top, 12)
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.manrope(28, .heavy))
                    .kerning(-0.9)
                    .foregroundStyle(t.fg)
                Text(label.uppercased())
                    .font(.manrope(11, .heavy))
                    .tracking(0.4)
                    .foregroundStyle(t.fg.opacity(0.75))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 84)
    }
}

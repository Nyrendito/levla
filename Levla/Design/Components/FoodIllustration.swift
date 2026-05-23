import SwiftUI

/// Per-food color palette — matches the design's FOOD table (warm pastels).
struct FoodPalette {
    let bg: Color
    let fg: Color
    let rim: Color
    let label: String

    static let table: [String: FoodPalette] = [
        // dairy
        "milk":     .init(bg: .init(hex: 0xF1ECE0), fg: .init(hex: 0xFAFAF6), rim: .init(hex: 0xE2DCC8), label: "milk"),
        "yogurt":   .init(bg: .init(hex: 0xF1ECE0), fg: .init(hex: 0xF4EFE2), rim: .init(hex: 0xD9C99A), label: "yogurt"),
        "butter":   .init(bg: .init(hex: 0xF4E9C9), fg: .init(hex: 0xE9C770), rim: .init(hex: 0xC9A23E), label: "butter"),
        "feta":     .init(bg: .init(hex: 0xF1ECE0), fg: .init(hex: 0xF8F4EA), rim: .init(hex: 0xD8CFB6), label: "feta"),
        "egg":      .init(bg: .init(hex: 0xF0E9D6), fg: .init(hex: 0xE9DAA8), rim: .init(hex: 0xC9A648), label: "eggs"),
        // veg
        "spinach":  .init(bg: .init(hex: 0xE1E9D2), fg: .init(hex: 0x6E8C4A), rim: .init(hex: 0x3F5E2A), label: "spinach"),
        "broccoli": .init(bg: .init(hex: 0xDCE6CC), fg: .init(hex: 0x5C7E40), rim: .init(hex: 0x3F5827), label: "broccoli"),
        "tomato":   .init(bg: .init(hex: 0xF3D6C6), fg: .init(hex: 0xC9543C), rim: .init(hex: 0x8D2C20), label: "tomato"),
        "carrot":   .init(bg: .init(hex: 0xF4DCC0), fg: .init(hex: 0xD4773A), rim: .init(hex: 0x9A4E20), label: "carrot"),
        "pepper":   .init(bg: .init(hex: 0xF1DBC4), fg: .init(hex: 0xD6692A), rim: .init(hex: 0x933B0E), label: "pepper"),
        "lemon":    .init(bg: .init(hex: 0xF4ECC0), fg: .init(hex: 0xE9C946), rim: .init(hex: 0xA98E1C), label: "lemon"),
        "garlic":   .init(bg: .init(hex: 0xEDE6D6), fg: .init(hex: 0xE9DFC2), rim: .init(hex: 0xB6A573), label: "garlic"),
        "onion":    .init(bg: .init(hex: 0xF1E6D0), fg: .init(hex: 0xD9B779), rim: .init(hex: 0x946B30), label: "onion"),
        "avocado":  .init(bg: .init(hex: 0xE0E5C7), fg: .init(hex: 0x7E904A), rim: .init(hex: 0x3F4F1F), label: "avocado"),
        // meat
        "chicken":  .init(bg: .init(hex: 0xF2E5D2), fg: .init(hex: 0xEBD3A8), rim: .init(hex: 0xB8884A), label: "chicken"),
        "salmon":   .init(bg: .init(hex: 0xF4DCC8), fg: .init(hex: 0xE59873), rim: .init(hex: 0xA6512B), label: "salmon"),
        "beef":     .init(bg: .init(hex: 0xEFD6CB), fg: .init(hex: 0xB65C4A), rim: .init(hex: 0x762924), label: "beef"),
        // pantry
        "rice":     .init(bg: .init(hex: 0xEFEADB), fg: .init(hex: 0xF1EAD0), rim: .init(hex: 0xC9B98C), label: "rice"),
        "pasta":    .init(bg: .init(hex: 0xF0E7CE), fg: .init(hex: 0xDCC58A), rim: .init(hex: 0x9A8348), label: "pasta"),
        "oil":      .init(bg: .init(hex: 0xF2E4B8), fg: .init(hex: 0xD5B354), rim: .init(hex: 0x917423), label: "olive oil"),
        "bread":    .init(bg: .init(hex: 0xF0DFB7), fg: .init(hex: 0xD5A664), rim: .init(hex: 0x8E5C28), label: "bread"),
        // drinks
        "wine":     .init(bg: .init(hex: 0xF1D8D5), fg: .init(hex: 0x7B2F3A), rim: .init(hex: 0x3D1419), label: "wine"),
        "water":    .init(bg: .init(hex: 0xE4EAEC), fg: .init(hex: 0xC7D7DC), rim: .init(hex: 0x7E9098), label: "water"),
        // misc
        "pesto":    .init(bg: .init(hex: 0xDEE5C9), fg: .init(hex: 0x637840), rim: .init(hex: 0x33421E), label: "pesto"),
        "parmesan": .init(bg: .init(hex: 0xF1E6C2), fg: .init(hex: 0xE1C77B), rim: .init(hex: 0x9F7F2D), label: "parmesan"),
    ]

    static func palette(for key: String) -> FoodPalette {
        table[key] ?? table["milk"]!
    }
}

/// Single-food illustration: a tinted blob over a pastel background.
/// Mirrors the design's V2 FoodIllustration — no real photos; CSS placeholders.
struct FoodIllustration: View {
    let food: String
    var size: CGFloat = 64

    var body: some View {
        let f = FoodPalette.palette(for: food)
        ZStack {
            switch food {
            case "chicken":
                Capsule()
                    .fill(f.fg)
                    .frame(width: size * 1.05, height: size * 0.74)
                    .rotationEffect(.degrees(-12))
                    .overlay(Capsule().stroke(f.rim.opacity(0.33), lineWidth: 0).frame(width: size * 1.05, height: size * 0.74).rotationEffect(.degrees(-12)))
            case "onion":
                ZStack(alignment: .top) {
                    Ellipse()
                        .fill(f.fg)
                        .frame(width: size * 0.78, height: size * 0.86)
                    Capsule()
                        .fill(Color(hex: 0x7A6A3D))
                        .frame(width: 5, height: 12)
                        .offset(y: -8)
                }
            case "garlic":
                Capsule()
                    .fill(f.fg)
                    .frame(width: size * 0.42, height: size * 0.92)
            case "tomato", "pepper":
                ZStack(alignment: .top) {
                    Circle()
                        .fill(f.fg)
                        .frame(width: size * 0.78, height: size * 0.78)
                    Capsule()
                        .fill(Color(hex: 0x3F5E2A))
                        .frame(width: 14, height: 8)
                        .offset(y: -4)
                }
            case "bread", "butter":
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(f.fg)
                    .frame(width: size * 0.92, height: size * 0.62)
            case "milk", "wine":
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(f.fg)
                    .frame(width: size * 0.5, height: size * 0.9)
            case "egg":
                Ellipse()
                    .fill(f.fg)
                    .frame(width: size * 0.7, height: size * 0.86)
            case "spinach", "broccoli", "avocado":
                ZStack {
                    Circle().fill(f.fg).frame(width: size * 0.78, height: size * 0.78)
                    Circle().fill(f.rim.opacity(0.18)).frame(width: size * 0.4, height: size * 0.4).offset(x: -size * 0.12, y: -size * 0.12)
                }
            default:
                Circle()
                    .fill(f.fg)
                    .frame(width: size * 0.78, height: size * 0.78)
            }
        }
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                .opacity(0.0001) // placeholder for shadow shape
        )
        .frame(width: size, height: size)
    }
}

/// Small rounded food "tile": colored bg square + a centered FoodIllustration.
struct FoodTile: View {
    let food: String
    var size: CGFloat = 44
    var radius: CGFloat = 14

    var body: some View {
        let f = FoodPalette.palette(for: food)
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(f.bg)
            FoodIllustration(food: food, size: size * 0.78)
        }
        .frame(width: size, height: size)
    }
}

/// FoodOrb — hero food art for recipe cards & detail. One large primary
/// orb + supporting smaller orbs over a warm wash.
struct FoodOrb: View {
    let foods: [String]
    let color: Color
    let accent: Color
    var height: CGFloat = 280
    var radius: CGFloat = L.R.xxl
    var label: String? = nil

    var body: some View {
        let arr = foods.isEmpty ? ["tomato"] : foods
        ZStack {
            color
            // wash gradient
            RadialGradient(
                colors: [Color.white.opacity(0.7), .clear],
                center: .init(x: 0.3, y: 0.0),
                startRadius: 0,
                endRadius: 300
            )
            RadialGradient(
                colors: [accent.opacity(0.22), .clear],
                center: .init(x: 0.9, y: 1.0),
                startRadius: 0,
                endRadius: 240
            )

            GeometryReader { g in
                let s = min(g.size.width, g.size.height)
                let primarySize = min(s * 0.62, 200)

                // shadow under primary
                Ellipse()
                    .fill(Color(hex: 0x282016).opacity(0.10))
                    .frame(width: primarySize * 0.9, height: primarySize * 0.18)
                    .blur(radius: 8)
                    .position(x: g.size.width * 0.5, y: g.size.height * 0.66)

                // primary orb
                orb(food: arr[0], size: primarySize)
                    .position(x: g.size.width * 0.5, y: g.size.height * 0.56)

                // supporting orbs
                if arr.count > 1 { orb(food: arr[1], size: 70).position(x: g.size.width * 0.22, y: g.size.height * 0.28) }
                if arr.count > 2 { orb(food: arr[2], size: 62).position(x: g.size.width * 0.80, y: g.size.height * 0.28) }
                if arr.count > 3 { orb(food: arr[3], size: 50).position(x: g.size.width * 0.80, y: g.size.height * 0.80) }
                if arr.count > 4 { orb(food: arr[4], size: 44).position(x: g.size.width * 0.18, y: g.size.height * 0.80) }
            }

            if let label {
                VStack {
                    Spacer()
                    HStack {
                        Text(label.uppercased())
                            .font(.mono(11))
                            .tracking(0.8)
                            .foregroundStyle(Color(hex: 0x282016).opacity(0.55))
                        Spacer()
                    }
                }
                .padding(.leading, 18)
                .padding(.bottom, 14)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    @ViewBuilder
    private func orb(food: String, size: CGFloat) -> some View {
        let f = FoodPalette.palette(for: food)
        Circle()
            .fill(f.fg)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(f.rim.opacity(0.35), lineWidth: 0)
            )
            .shadow(color: Color(hex: 0x282016).opacity(0.10), radius: size * 0.18, x: 0, y: size * 0.06)
    }
}

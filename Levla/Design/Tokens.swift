import SwiftUI

/// Levla design tokens — warm cream paper, ink, sage mint, clay coral.
/// Mirrors the design's V2 token set (Manrope, rCard 28, rBtn 22, btnH 62).
enum L {
    // MARK: - Type
    static let manrope = "Manrope"
    static let mono = "JetBrainsMono-Medium"

    // MARK: - Surfaces (low-chroma warm whites)
    static let paper = Color(hex: 0xF6F1E6)        // app background
    static let cream = Color(hex: 0xFFF8EC)        // warmer surface
    static let surface = Color(hex: 0xFAF7F1)      // primary surface
    static let card = Color.white                  // raised card
    static let inset = Color(hex: 0xEFEAE0)        // tag chip background
    static let hairline = Color(hex: 0x282016).opacity(0.07)
    static let hairline2 = Color(hex: 0x282016).opacity(0.12)

    // MARK: - Ink
    static let ink = Color(hex: 0x1F1D1A)
    static let ink2 = Color(hex: 0x3A3530)
    static let muted = Color(hex: 0x7A7268)
    static let muted2 = Color(hex: 0x9A9088)

    // MARK: - Accents (V2 "viral" palette)
    static let pop = Color(hex: 0xE97A47)          // clay coral — primary accent
    static let popDark = Color(hex: 0x7C3A18)
    static let popBg = Color(hex: 0xFFE9D7)
    static let mint = Color(hex: 0x7BAE61)         // sage green — fresh
    static let mintBg = Color(hex: 0xDCEDC8)
    static let sun = Color(hex: 0xF2C24A)          // honey — low stock
    static let sunBg = Color(hex: 0xFFF1C7)
    static let sunFg = Color(hex: 0xB58418)
    static let rose = Color(hex: 0xD54E55)         // alarm red — use today
    static let roseBg = Color(hex: 0xFCDDD8)

    // Food-tile pastel backgrounds
    static let pTomato = Color(hex: 0xF4DCC8)
    static let pButter = Color(hex: 0xF1E6C2)
    static let pCream = Color(hex: 0xF1ECDE)
    static let pSage = Color(hex: 0xDCEDC8)

    // MARK: - Radii
    enum R {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 22       // V2 button radius
        static let xxl: CGFloat = 28      // V2 card radius
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing
    enum S {
        static let pad: CGFloat = 22
        static let gap: CGFloat = 12
        static let gapSm: CGFloat = 8
        static let gapLg: CGFloat = 18
    }

    // MARK: - Buttons
    static let btnHeight: CGFloat = 62

    // MARK: - Shadows
    enum Shadow {
        static func card<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x282016).opacity(0.06), radius: 6, x: 0, y: 2)
             .shadow(color: Color(hex: 0x282016).opacity(0.08), radius: 18, x: 0, y: 8)
        }
        static func lift<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x282016).opacity(0.05), radius: 4, x: 0, y: 2)
             .shadow(color: Color(hex: 0x282016).opacity(0.10), radius: 20, x: 0, y: 10)
        }
        static func soft<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x282016).opacity(0.05), radius: 14, x: 0, y: 4)
        }
        static func button<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x1F1D1A).opacity(0.28), radius: 12, x: 0, y: 8)
        }
        static func pop<V: View>(_ v: V) -> some View {
            v.shadow(color: L.pop.opacity(0.35), radius: 15, x: 0, y: 10)
        }
        static func mint<V: View>(_ v: V) -> some View {
            v.shadow(color: L.mint.opacity(0.32), radius: 14, x: 0, y: 8)
        }
    }
}

// MARK: - Color hex initializer
extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Font helpers
extension Font {
    static func manrope(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom(L.manrope, size: size).weight(weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        Font.custom(L.mono, size: size)
    }
}

// MARK: - Tap feedback modifier ("v2-tap")
struct TapPress: ViewModifier {
    @State private var pressed = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    func tapPress() -> some View { modifier(TapPress()) }
}

import SwiftUI

/// Levla design tokens — refreshed Lifesum-inspired palette.
/// Sage green primary, near-white card surfaces over a soft cream background,
/// generous spacing, hairline dividers. Manrope throughout.
enum L {
    // MARK: - Type
    static let manrope = "Manrope"
    static let mono = "JetBrainsMono-Medium"

    // MARK: - Surfaces (Lifesum: warm cream BG, pure white cards)
    static let paper    = Color(hex: 0xF4F1ED)     // app background, slightly lighter cream
    static let cream    = Color(hex: 0xFFFDF7)     // hero surfaces / dark-mode cream
    static let surface  = Color(hex: 0xFBF9F4)     // secondary surface
    static let card     = Color.white              // raised card surface
    static let inset    = Color(hex: 0xF0EDE6)     // tag chips, hairline backgrounds
    static let hairline = Color(hex: 0x1F1D1A).opacity(0.06)
    static let hairline2 = Color(hex: 0x1F1D1A).opacity(0.10)

    // MARK: - Ink
    static let ink   = Color(hex: 0x18181A)        // primary text
    static let ink2  = Color(hex: 0x3A3530)
    static let muted = Color(hex: 0x7E7872)
    static let muted2 = Color(hex: 0xA09A93)

    // MARK: - Brand & accents
    /// PRIMARY brand green (Lifesum-like sage). Used for primary CTAs,
    /// active tab indicator, brand wordmark accent.
    static let brand     = Color(hex: 0x5DBC83)
    static let brandDark = Color(hex: 0x2E7A4E)
    static let brandBg   = Color(hex: 0xDDF0E4)

    /// Legacy aliases — kept so existing call sites compile; they map to the
    /// refreshed palette.
    static let mint    = brand
    static let mintBg  = brandBg

    /// Coral / orange — Levla's secondary brand color. Used for the center
    /// Scan FAB and emphasis tags.
    static let pop     = Color(hex: 0xEA7649)
    static let popDark = Color(hex: 0x7C3A18)
    static let popBg   = Color(hex: 0xFCE3D5)

    /// Heart / favourite color, matches Lifesum.
    static let heart   = Color(hex: 0xF4665C)
    static let heartBg = Color(hex: 0xFDE2DF)

    /// Honey for "low stock" tag.
    static let sun     = Color(hex: 0xE4B33A)
    static let sunBg   = Color(hex: 0xFFF1C7)
    static let sunFg   = Color(hex: 0xA07215)

    /// Alarm red (kept for future use; currently we don't surface it).
    static let rose    = Color(hex: 0xD54E55)
    static let roseBg  = Color(hex: 0xFCDDD8)

    // MARK: - Macro accent palette (Cal AI / Lifesum convention)
    static let macroCarbs   = Color(hex: 0xE4B33A)   // yellow
    static let macroFat     = Color(hex: 0x6A8DDA)   // soft blue
    static let macroProtein = Color(hex: 0x5DBC83)   // green

    // Food-tile pastel backgrounds
    static let pTomato = Color(hex: 0xF4DCC8)
    static let pButter = Color(hex: 0xF1E6C2)
    static let pCream = Color(hex: 0xF1ECDE)
    static let pSage = Color(hex: 0xDCEDC8)

    // MARK: - Radii (Lifesum favours softer corners)
    enum R {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20       // primary card radius
        static let xxl: CGFloat = 28      // hero radius
        static let pill: CGFloat = 999
    }

    // MARK: - Spacing — generous, Lifesum-style breathing room
    enum S {
        static let pad: CGFloat = 22
        static let gap: CGFloat = 14
        static let gapSm: CGFloat = 8
        static let gapLg: CGFloat = 22
        /// Vertical rhythm between sections on the same screen.
        static let section: CGFloat = 32
    }

    // MARK: - Buttons (Lifesum pill heights)
    static let btnHeight: CGFloat = 56

    // MARK: - Shadows — flatter than before; Lifesum cards are nearly flat
    enum Shadow {
        static func card<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x1F1D1A).opacity(0.04), radius: 6, x: 0, y: 2)
             .shadow(color: Color(hex: 0x1F1D1A).opacity(0.04), radius: 14, x: 0, y: 6)
        }
        static func lift<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x1F1D1A).opacity(0.05), radius: 6, x: 0, y: 4)
             .shadow(color: Color(hex: 0x1F1D1A).opacity(0.07), radius: 18, x: 0, y: 10)
        }
        static func soft<V: View>(_ v: V) -> some View {
            v.shadow(color: Color(hex: 0x1F1D1A).opacity(0.04), radius: 10, x: 0, y: 4)
        }
        static func button<V: View>(_ v: V) -> some View {
            v.shadow(color: L.brand.opacity(0.28), radius: 12, x: 0, y: 6)
        }
        static func pop<V: View>(_ v: V) -> some View {
            v.shadow(color: L.pop.opacity(0.30), radius: 14, x: 0, y: 8)
        }
        static func mint<V: View>(_ v: V) -> some View {
            v.shadow(color: L.brand.opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }
}

// MARK: - Lifesum-style section header (small uppercase tracked)

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.manrope(11, .heavy))
            .tracking(1.6)
            .foregroundStyle(L.ink.opacity(0.55))
    }
}

/// Hairline divider — used between list rows. Lifesum's signature.
struct Hairline: View {
    var inset: CGFloat = 0
    var body: some View {
        Rectangle()
            .fill(L.hairline)
            .frame(height: 0.5)
            .padding(.leading, inset)
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

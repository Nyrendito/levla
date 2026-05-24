import SwiftUI

/// Lifesum-style primary action button: pill, uppercase, soft green by
/// default. `.pop` = coral, `.ink` = dark, `.light` = white.
struct BigCTA: View {
    enum Kind { case primary, pop, ink, light, sun }
    enum Size { case sm, md, lg }

    let title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var size: Size = .lg
    var subtle: Bool = false
    var action: () -> Void = {}

    private var bg: Color {
        switch kind {
        case .primary: return L.brand
        case .pop:     return L.pop
        case .ink:     return L.ink
        case .light:   return .white
        case .sun:     return L.sun
        }
    }
    private var fg: Color {
        switch kind { case .light: return L.ink; default: return .white }
    }
    private var h: CGFloat {
        switch size { case .sm: return 44; case .md: return 50; case .lg: return L.btnHeight }
    }
    private var fontSize: CGFloat { size == .sm ? 13 : 14 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule().fill(bg)
                HStack(spacing: 10) {
                    if let icon { LSymbol(key: icon, size: 18, weight: .semibold) }
                    Text(title.uppercased())
                        .font(.manrope(fontSize, .heavy))
                        .tracking(1.4)
                }
                .foregroundStyle(fg)
            }
            .frame(maxWidth: .infinity)
            .frame(height: h)
        }
        .buttonStyle(.plain)
        .modifier(_BigCTAShadow(kind: kind))
        .tapPress()
    }
}

private struct _BigCTAShadow: ViewModifier {
    let kind: BigCTA.Kind
    func body(content: Content) -> some View {
        switch kind {
        case .primary: L.Shadow.mint(content)
        case .pop:     L.Shadow.pop(content)
        case .ink:     L.Shadow.button(content)
        case .light:   L.Shadow.soft(content)
        case .sun:     L.Shadow.soft(content)
        }
    }
}

/// Round 44pt icon button — used in headers.
struct BigIconBtn: View {
    enum Tone { case light, ink, pop, brand }
    let icon: String
    var tone: Tone = .light
    var size: CGFloat = 44
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(toneBg)
                LSymbol(key: icon, size: 18, weight: .semibold).foregroundStyle(toneFg)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .modifier(_BigIconShadow())
        .tapPress()
    }

    private var toneBg: Color {
        switch tone { case .light: return .white; case .ink: return L.ink; case .pop: return L.pop; case .brand: return L.brand }
    }
    private var toneFg: Color {
        switch tone { case .light: return L.ink; default: return .white }
    }
}

private struct _BigIconShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

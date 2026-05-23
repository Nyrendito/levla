import SwiftUI

/// 62pt-tall confident button — the "you can't miss it" CTA.
struct BigCTA: View {
    enum Kind { case primary, pop, mint, light, sun }
    enum Size { case sm, md, lg }

    let title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var size: Size = .lg
    var subtle: Bool = false
    var action: () -> Void = {}

    private var bg: Color {
        switch kind { case .primary: return L.ink; case .pop: return L.pop; case .mint: return L.mint; case .light: return .white; case .sun: return L.sun }
    }
    private var fg: Color {
        switch kind { case .light: return L.ink; default: return L.cream }
    }
    private var h: CGFloat {
        switch size { case .sm: return 48; case .md: return 56; case .lg: return L.btnHeight }
    }
    private var fontSize: CGFloat { size == .sm ? 15 : 17 }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous).fill(bg)
                HStack(spacing: 10) {
                    if let icon { LSymbol(key: icon, size: 20, weight: .semibold) }
                    Text(title)
                        .font(.manrope(fontSize, .heavy))
                        .kerning(-0.3)
                    if !subtle, kind == .primary {
                        Spacer()
                        LSymbol(key: "arrowR", size: 18, weight: .semibold)
                    }
                }
                .padding(.horizontal, kind == .primary && !subtle ? 22 : 0)
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
        case .primary: L.Shadow.button(content)
        case .pop:     L.Shadow.pop(content)
        case .mint:    L.Shadow.mint(content)
        case .light:   L.Shadow.soft(content)
        case .sun:     L.Shadow.soft(content)
        }
    }
}

/// Round 48pt icon button used in headers.
struct BigIconBtn: View {
    enum Tone { case light, ink, pop }
    let icon: String
    var tone: Tone = .light
    var size: CGFloat = 48
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(toneBg)
                LSymbol(key: icon, size: 20, weight: .semibold).foregroundStyle(toneFg)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .modifier(_BigIconShadow())
        .tapPress()
    }

    private var toneBg: Color { switch tone { case .light: return .white; case .ink: return L.ink; case .pop: return L.pop } }
    private var toneFg: Color { switch tone { case .light: return L.ink; default: return L.cream } }
}

private struct _BigIconShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

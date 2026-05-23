import SwiftUI

/// Color-toned chip — used in recipe detail (use today / low / buy / in fridge).
struct LPill<Content: View>: View {
    enum Tone { case pop, sun, mint, ink, neutral }
    var tone: Tone = .mint
    @ViewBuilder var content: () -> Content

    private var palette: (bg: Color, fg: Color) {
        switch tone {
        case .pop:     return (L.popBg, L.pop)
        case .sun:     return (L.sunBg, L.sunFg)
        case .mint:    return (L.mintBg, L.mint)
        case .ink:     return (L.ink, L.cream)
        case .neutral: return (L.ink.opacity(0.06), L.ink.opacity(0.6))
        }
    }

    var body: some View {
        HStack(spacing: 4) { content() }
            .font(.manrope(12, .heavy))
            .kerning(-0.1)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(palette.bg, in: Capsule())
            .foregroundStyle(palette.fg)
    }
}

/// BigSectionTitle — bigger, bolder section header per design.
struct BigSectionTitle<Action: View>: View {
    let title: String
    var hint: String? = nil
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.manrope(22, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.ink)
                if let hint {
                    Text(hint)
                        .font(.manrope(13.5, .medium))
                        .foregroundStyle(L.ink.opacity(0.55))
                }
            }
            Spacer()
            action()
        }
    }
}

/// BigHeader — large screen title row used at the top of each tab.
struct BigHeader<Right: View>: View {
    let title: String
    var sub: String? = nil
    @ViewBuilder var right: () -> Right

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                if let sub {
                    Text(sub.uppercased())
                        .font(.manrope(12.5, .heavy))
                        .tracking(0.6)
                        .foregroundStyle(L.ink.opacity(0.55))
                }
                Text(title)
                    .font(.manrope(36, .heavy))
                    .kerning(-1.2)
                    .foregroundStyle(L.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            right()
        }
        .padding(.top, 60)
        .padding(.bottom, 8)
    }
}

/// InfoBanner — Cal-AI-style bell + text banner used on Home.
struct InfoBanner: View {
    let icon: String
    let text: String
    @State private var open = true

    var body: some View {
        if open {
            HStack(spacing: 12) {
                LSymbol(key: icon, size: 22, weight: .regular)
                    .foregroundStyle(L.ink.opacity(0.5))
                Text(text)
                    .font(.manrope(13.5, .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(L.ink.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { withAnimation { open = false } } label: {
                    LSymbol(key: "close", size: 16, weight: .semibold)
                        .foregroundStyle(L.ink.opacity(0.45))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(L.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

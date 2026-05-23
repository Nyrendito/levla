import SwiftUI

/// Bottom sheet shown when the user taps the center Scan FAB.
/// Two big choices (Scan fridge / Scan receipt) + three minis (Barcode / Voice / Manual).
struct ScanSheetView: View {
    let onFridge: () -> Void
    let onReceipt: () -> Void
    let onBarcode: () -> Void
    let onVoice: () -> Void
    let onManual: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What are we adding?")
                    .font(.manrope(24, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Text("Pick one — Levla does the rest.")
                    .font(.manrope(13.5, .medium))
                    .foregroundStyle(L.ink.opacity(0.55))
            }

            HStack(spacing: 12) {
                ScanChoiceCard(icon: "fridge",  title: "Scan fridge",  sub: "One shot, AI does the rest", tone: .mint, action: onFridge)
                ScanChoiceCard(icon: "receipt", title: "Scan receipt", sub: "Fills your fridge in one go",    tone: .pop,  action: onReceipt)
            }
            .padding(.top, 18)

            VStack(spacing: 8) {
                ScanMiniRow(icon: "scan",  label: "Scan a barcode",      sub: "Quickly add a single product",  action: onBarcode)
                ScanMiniRow(icon: "mic",   label: "Say what you bought", sub: "Voice quick-add",               action: onVoice)
                ScanMiniRow(icon: "plus",  label: "Add one item by hand",sub: "The slow way",                  action: onManual)
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(L.paper.ignoresSafeArea())
    }
}

struct ScanChoiceCard: View {
    enum Tone { case pop, mint }
    let icon: String
    let title: String
    let sub: String
    let tone: Tone
    let action: () -> Void

    private var bg: Color { tone == .pop ? L.pop : L.mint }
    private var ring: Color { L.cream.opacity(0.20) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ring)
                    LSymbol(key: icon, size: 26, weight: .semibold).foregroundStyle(L.cream)
                }
                .frame(width: 48, height: 48)
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.manrope(17, .heavy))
                        .kerning(-0.4)
                    Text(sub)
                        .font(.manrope(12.5, .semibold))
                        .opacity(0.78)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
            .background(bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foregroundStyle(L.cream)
        }
        .buttonStyle(.plain)
        .shadow(color: bg.opacity(0.30), radius: 18, x: 0, y: 12)
        .tapPress()
    }
}

struct ScanMiniRow: View {
    let icon: String
    let label: String
    let sub: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(L.ink.opacity(0.06))
                    LSymbol(key: icon, size: 18, weight: .semibold).foregroundStyle(L.ink)
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.manrope(14, .heavy)).kerning(-0.2).foregroundStyle(L.ink)
                    Text(sub).font(.manrope(11.5, .semibold)).foregroundStyle(L.ink.opacity(0.5))
                }
                Spacer()
                LSymbol(key: "chevron", size: 16, weight: .semibold).foregroundStyle(L.ink.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_MiniRowShadow())
        .tapPress()
    }
}

private struct _MiniRowShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}

import SwiftUI

/// Slim bottom sheet shown when the user taps the center Scan FAB.
///
/// Cal-AI-style two-option router: pick *what* you're adding (fridge items
/// or a logged meal). The actual mode (fridge / receipt / barcode / library)
/// is selected *inside* the camera screen via its bottom mode bar — no
/// need to back out to switch.
struct ScanSheetView: View {
    let onAddToFridge: () -> Void
    let onLogMeal: () -> Void

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
                ScanChoiceCard(
                    icon: "fridge",
                    title: "Add to fridge",
                    sub: "Scan fridge, a receipt, a barcode, or pick a photo.",
                    tone: .mint,
                    action: onAddToFridge
                )
                ScanChoiceCard(
                    icon: "camera",
                    title: "Log a meal",
                    sub: "Snap your plate — get kcal, protein, carbs, fat.",
                    tone: .pop,
                    action: onLogMeal
                )
            }
            .padding(.top, 18)
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
                        .opacity(0.85)
                }
                .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
            .background(bg, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foregroundStyle(L.cream)
        }
        .buttonStyle(.plain)
        .shadow(color: bg.opacity(0.30), radius: 18, x: 0, y: 12)
        .tapPress()
    }
}

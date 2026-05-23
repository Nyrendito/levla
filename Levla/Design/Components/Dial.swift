import SwiftUI

/// Radial dial: track ring + arc + centered icon — used on Home tracking carousel.
struct Dial: View {
    let pct: Double                    // 0…1
    var size: CGFloat = 120
    var stroke: CGFloat = 12
    var icon: String = "leaf"
    var tone: Color = L.mint
    var bg: Color? = nil
    var mini: Bool = false

    var body: some View {
        let r = (size - stroke) / 2
        ZStack {
            // track
            Circle()
                .stroke(bg ?? Color(hex: 0x1F1D1A).opacity(0.06), lineWidth: stroke)
                .frame(width: r * 2, height: r * 2)
            // arc
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, pct))))
                .stroke(tone, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .frame(width: r * 2, height: r * 2)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(bg ?? Color(hex: 0x1F1D1A).opacity(0.04))
                .frame(width: size - stroke * 2 - 8, height: size - stroke * 2 - 8)

            LSymbol(key: icon, size: mini ? 18 : 30, weight: .semibold)
                .foregroundStyle(tone)
        }
        .frame(width: size, height: size)
    }
}

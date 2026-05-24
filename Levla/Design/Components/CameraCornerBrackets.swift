import SwiftUI

/// Minimalist camera viewfinder — four rounded L-shaped brackets in the
/// corners of the screen, like a native camera. No central rectangle, no
/// hard edges; just enough to suggest "this is a viewfinder" without
/// boxing the content in.
///
/// Used by the unified scan flow and the meal logger to replace the older
/// inner-padded ViewfinderCorners (which centred a tiny box in the middle
/// and fought with the mode bar / shutter).
struct CameraCornerBrackets: View {
    /// Distance from each screen edge to the bracket. Default keeps the
    /// brackets visible alongside the top chrome buttons and well clear of
    /// the bottom mode bar + shutter row.
    var topInset: CGFloat = 110
    var bottomInset: CGFloat = 220
    var sideInset: CGFloat = 24

    /// Length of each leg of the L.
    var size: CGFloat = 26
    /// Stroke thickness.
    var lineWidth: CGFloat = 2.5
    /// Bracket color — kept light so it reads on a dark camera preview.
    var color: Color = .white.opacity(0.85)
    /// Corner radius where the two legs meet.
    var cornerRadius: CGFloat = 4

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    bracket(.topLeading)
                    Spacer()
                    bracket(.topTrailing)
                }
                Spacer()
                HStack {
                    bracket(.bottomLeading)
                    Spacer()
                    bracket(.bottomTrailing)
                }
            }
            .padding(.top, topInset)
            .padding(.bottom, bottomInset)
            .padding(.horizontal, sideInset)
        }
        .allowsHitTesting(false)
    }

    private func bracket(_ pos: Position) -> some View {
        Path { p in
            switch pos {
            case .topLeading:
                p.move(to: CGPoint(x: 0, y: size))
                p.addLine(to: CGPoint(x: 0, y: cornerRadius))
                p.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: 0),
                    control: .zero
                )
                p.addLine(to: CGPoint(x: size, y: 0))
            case .topTrailing:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size - cornerRadius, y: 0))
                p.addQuadCurve(
                    to: CGPoint(x: size, y: cornerRadius),
                    control: CGPoint(x: size, y: 0)
                )
                p.addLine(to: CGPoint(x: size, y: size))
            case .bottomLeading:
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 0, y: size - cornerRadius))
                p.addQuadCurve(
                    to: CGPoint(x: cornerRadius, y: size),
                    control: CGPoint(x: 0, y: size)
                )
                p.addLine(to: CGPoint(x: size, y: size))
            case .bottomTrailing:
                p.move(to: CGPoint(x: 0, y: size))
                p.addLine(to: CGPoint(x: size - cornerRadius, y: size))
                p.addQuadCurve(
                    to: CGPoint(x: size, y: size - cornerRadius),
                    control: CGPoint(x: size, y: size)
                )
                p.addLine(to: CGPoint(x: size, y: 0))
            }
        }
        .stroke(
            color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
        .frame(width: size, height: size)
    }

    private enum Position { case topLeading, topTrailing, bottomLeading, bottomTrailing }
}

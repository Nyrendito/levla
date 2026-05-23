import SwiftUI

/// Quiet 6px AI presence dot — design's "quiet AI" affordance.
struct AIDot: View {
    var color: Color = L.mint
    var size: CGFloat = 6

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

/// Initials avatar — used in the shopping list "shared with partner" affordance.
struct Avatar: View {
    let name: String
    var color: Color = L.mint
    var size: CGFloat = 32

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.first ?? Character("?")) }.joined()
    }

    var body: some View {
        ZStack {
            Circle().fill(color)
            Text(initials)
                .font(.manrope(size * 0.42, .heavy))
                .foregroundStyle(L.cream)
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(L.paper, lineWidth: 2))
    }
}

/// Status bar spacer — matches design's StatusBar layout offset.
struct LStatusBarSpace: View {
    var dark: Bool = false
    var body: some View {
        Color.clear.frame(height: 44)
    }
}

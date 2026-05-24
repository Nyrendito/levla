import SwiftUI

/// Cal-AI-style mode switcher overlay shown just above the shutter button.
/// Four pill tabs — Scan fridge / Scan receipt / Barcode / Library — let the
/// user switch capture mode without backing out to the bottom sheet.
///
/// The active tab is filled white, the rest are translucent so they read
/// against the dark camera preview.
struct ScanModeBar: View {
    @Binding var selected: ScanMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                tab(for: mode)
            }
        }
        .padding(6)
        .background(
            Capsule().fill(Color.black.opacity(0.35))
        )
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func tab(for mode: ScanMode) -> some View {
        let active = mode == selected
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selected = mode
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(active ? L.ink : Color.white.opacity(0.85))
                Text(mode.shortLabel)
                    .font(.manrope(10, .heavy))
                    .tracking(0.2)
                    .foregroundStyle(active ? L.ink : Color.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(active ? Color.white : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .tapPress()
    }
}

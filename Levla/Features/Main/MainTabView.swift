import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @State private var scanSheetOpen = false
    @State private var presentedScan: ScanKind? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            L.paper.ignoresSafeArea()

            content

            BigTabBar(
                selected: bindingTab,
                onScan: { scanSheetOpen = true }
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $scanSheetOpen) {
            ScanSheetView(
                onFridge:  { scanSheetOpen = false; presentedScan = .fridge },
                onReceipt: { scanSheetOpen = false; presentedScan = .receipt },
                onBarcode: { scanSheetOpen = false; presentedScan = .barcode },
                onVoice:   { scanSheetOpen = false },
                onManual:  { scanSheetOpen = false }
            )
            .presentationDetents([.height(540)])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
            .presentationBackground(L.paper)
        }
        .fullScreenCover(item: $presentedScan) { kind in
            ScanFlowView(kind: kind) {
                presentedScan = nil
            }
        }
    }

    private var bindingTab: Binding<MainTab> {
        Binding(get: { app.selectedTab }, set: { app.selectedTab = $0 })
    }

    @ViewBuilder
    private var content: some View {
        switch app.selectedTab {
        case .home:   HomeView()
        case .fridge: FridgeView()
        case .cook:   CookDeckView()
        case .list:   ShoppingView()
        }
    }
}

extension ScanKind: Identifiable {
    public var id: String { rawValue }
}

/// Floating bottom tab bar — 4 tabs split around a center Scan FAB.
struct BigTabBar: View {
    @Binding var selected: MainTab
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tab(.home, "home", "Home", L.pop)
            tab(.fridge, "fridge", "Fridge", L.mint)

            // Center Scan FAB
            Button(action: onScan) {
                ZStack {
                    Circle()
                        .fill(L.pop)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                    LSymbol(key: "scan", size: 26, weight: .bold).foregroundStyle(L.cream)
                }
                .shadow(color: L.pop.opacity(0.4), radius: 12, x: 0, y: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .tapPress()

            tab(.cook, "recipe", "Cook", L.sun)
            tab(.list, "cart", "List", L.mint)
        }
        .frame(height: 76)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(L.cream.opacity(0.94))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color(hex: 0x282016).opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color(hex: 0x282016).opacity(0.14), radius: 16, x: 0, y: 8)
    }

    private func tab(_ t: MainTab, _ icon: String, _ label: String, _ color: Color) -> some View {
        let active = selected == t
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { selected = t }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Capsule()
                        .fill(active ? color : .clear)
                        .frame(width: active ? 48 : 40, height: active ? 36 : 30)
                    LSymbol(key: icon, size: active ? 22 : 22, weight: .semibold)
                        .foregroundStyle(active ? L.cream : L.ink)
                }
                Text(label)
                    .font(.manrope(11.5, active ? .heavy : .semibold))
                    .foregroundStyle(active ? L.ink : L.ink.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .tapPress()
    }
}

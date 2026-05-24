import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @State private var scanSheetOpen = false
    @State private var presentedScan: ScanKind? = nil

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                L.paper.ignoresSafeArea()
                content
            }
            BigTabBar(
                selected: bindingTab,
                onScan: { scanSheetOpen = true }
            )
        }
        .background(L.paper)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $scanSheetOpen) {
            ScanSheetView(
                onFridge:   { scanSheetOpen = false; presentedScan = .fridge },
                onReceipt:  { scanSheetOpen = false; presentedScan = .receipt },
                onBarcode:  { scanSheetOpen = false; presentedScan = .barcode },
                onVoice:    { scanSheetOpen = false },
                onLogMeal:  { scanSheetOpen = false; app.presentingLogMeal = true }
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
        // HomeView and other in-app surfaces can request a scan by setting
        // `app.presentingScan` — mirror that into the local @State that drives
        // the fullScreenCover.
        .onChange(of: app.presentingScan) { _, new in
            if let kind = new {
                presentedScan = kind
                app.presentingScan = nil
            }
        }
        .sheet(isPresented: bindingProfile) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: bindingLogMeal) {
            LogMealView { app.presentingLogMeal = false }
        }
    }

    private var bindingProfile: Binding<Bool> {
        Binding(get: { app.presentingProfile }, set: { app.presentingProfile = $0 })
    }

    private var bindingLogMeal: Binding<Bool> {
        Binding(get: { app.presentingLogMeal }, set: { app.presentingLogMeal = $0 })
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

/// Lifesum-style bottom bar: subtle gray icons, green active, center
/// green disc with white plus. Sits as an opaque white surface with a
/// hairline above it (flat, not a floating pill).
struct BigTabBar: View {
    @Binding var selected: MainTab
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                tab(.home,   "home",   "Home")
                tab(.fridge, "fridge", "Fridge")

                // Center Scan FAB — green disc with white plus / scan.
                Button(action: onScan) {
                    ZStack {
                        Circle()
                            .fill(L.brand)
                            .frame(width: 56, height: 56)
                        LSymbol(key: "scan", size: 24, weight: .heavy).foregroundStyle(.white)
                    }
                    .shadow(color: L.brand.opacity(0.36), radius: 10, x: 0, y: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .tapPress()

                tab(.cook,  "recipe", "Cook")
                tab(.list,  "cart",   "List")
            }
            .frame(height: 64)
            .padding(.bottom, 6)
        }
        .background(Color.white.ignoresSafeArea(edges: .bottom))
    }

    private func tab(_ t: MainTab, _ icon: String, _ label: String) -> some View {
        let active = selected == t
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selected = t }
        } label: {
            VStack(spacing: 4) {
                LSymbol(key: icon, size: 22, weight: active ? .bold : .regular)
                    .foregroundStyle(active ? L.brand : L.muted)
                Text(label)
                    .font(.manrope(10.5, active ? .heavy : .semibold))
                    .foregroundStyle(active ? L.brand : L.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .tapPress()
    }
}

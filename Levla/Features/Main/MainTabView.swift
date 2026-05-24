import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var app
    @State private var scanSheetOpen = false
    /// What mode to open the unified scan camera in. nil means it's closed.
    /// The user picks Add-to-fridge or Log-a-meal in the ScanSheet; from
    /// inside the camera they swap fridge / receipt / barcode / library
    /// inline via the bottom mode bar.
    @State private var presentedScanMode: ScanMode? = nil

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
                onAddToFridge: {
                    scanSheetOpen = false
                    presentedScanMode = .fridge
                },
                onLogMeal: {
                    scanSheetOpen = false
                    app.presentingLogMeal = true
                }
            )
            .presentationDetents([.height(340)])
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
            .presentationBackground(L.paper)
        }
        .fullScreenCover(item: $presentedScanMode) { mode in
            ScanFlowView(initialMode: mode) {
                presentedScanMode = nil
            }
        }
        // HomeView and other in-app surfaces can still request a specific
        // mode via `app.presentingScan` — mirror that into the local @State.
        .onChange(of: app.presentingScan) { _, new in
            if let kind = new {
                presentedScanMode = ScanMode.fromKind(kind)
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

extension ScanMode: Identifiable {
    var id: String { rawValue }
    /// Map a legacy `ScanKind` (still used internally by AppState +
    /// `IdentifyingStage`) to the new unified mode enum.
    static func fromKind(_ k: ScanKind) -> ScanMode {
        switch k {
        case .fridge:  return .fridge
        case .receipt: return .receipt
        case .barcode: return .barcode
        }
    }
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

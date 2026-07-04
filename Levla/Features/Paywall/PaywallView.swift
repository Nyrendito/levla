import SwiftUI
import StoreKit

/// Levla Pro paywall. Renders whatever subscription products loaded from
/// App Store Connect — if a plan is still pending review it simply won't
/// appear, and the remaining plan(s) stay fully purchasable. Only a *totally*
/// empty catalog (network failure / nothing approved) shows the retry state.
struct PaywallView: View {
    @Environment(AppState.self) private var app
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var error: String?
    @State private var pendingNote: Bool = false

    private var store: StoreService { app.store }

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 24) {
                        hero
                        benefits
                        planList
                    }
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                footer
            }
        }
        .task {
            if store.products.isEmpty { await store.bootstrap() }
            syncSelection()
        }
        .onChange(of: store.products.map(\.id)) { _, _ in syncSelection() }
        .onChange(of: store.isPro) { _, isPro in if isPro { onClose() } }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onClose) {
                LSymbol(key: "close", size: 16, weight: .bold)
                    .foregroundStyle(L.ink)
                    .frame(width: 38, height: 38)
                    .background(.white, in: Circle())
                    .modifier(_PayShadow())
            }
            .buttonStyle(.plain)
            Spacer()
            Button {
                Task { await restore() }
            } label: {
                Text("Restore")
                    .font(.manrope(13, .heavy))
                    .foregroundStyle(L.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, L.S.pad)
        .padding(.top, 12)
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(L.brandBg).frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(L.brand)
            }
            VStack(spacing: 8) {
                Text("Levla Pro")
                    .font(.manrope(32, .heavy))
                    .kerning(-0.8)
                    .foregroundStyle(L.ink)
                Text("Unlimited scans, AI meal plans, and\nsmart recipes from your fridge.")
                    .font(.manrope(15, .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(L.ink.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Benefits

    private let perks: [(String, String)] = [
        ("scan",   "Unlimited fridge & meal scans"),
        ("sparkle","AI meal plans tuned to your goals"),
        ("recipe", "Smart recipes from what you have"),
        ("chart",  "Full progress history & insights"),
    ]

    private var benefits: some View {
        VStack(spacing: 12) {
            ForEach(perks, id: \.1) { icon, label in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(L.brandBg).frame(width: 34, height: 34)
                        LSymbol(key: icon, size: 15, weight: .bold).foregroundStyle(L.brand)
                    }
                    Text(label)
                        .font(.manrope(14.5, .heavy))
                        .kerning(-0.2)
                        .foregroundStyle(L.ink)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .modifier(_PayShadow())
    }

    // MARK: - Plans

    @ViewBuilder
    private var planList: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView().tint(L.brand).frame(maxWidth: .infinity).padding(.vertical, 30)
        case .failed(let msg):
            emptyState(msg)
        case .loaded:
            // Render exactly the products that came back. If one plan is still
            // pending on App Store Connect it's simply absent here — the rest
            // still render and are purchasable.
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    PlanRow(
                        product: product,
                        badge: badge(for: product),
                        selected: selectedID == product.id
                    ) { selectedID = product.id }
                }
            }
        }
    }

    private func emptyState(_ msg: String) -> some View {
        VStack(spacing: 14) {
            Text(msg)
                .font(.manrope(14, .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(L.muted)
            Button {
                Task { await store.loadProducts(); syncSelection() }
            } label: {
                Text("Try again")
                    .font(.manrope(13, .heavy))
                    .tracking(1.0)
                    .foregroundStyle(L.brand)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            if let error {
                Text(error)
                    .font(.manrope(12.5, .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(L.rose)
            }
            if pendingNote {
                Text("Your purchase is pending approval. Pro will unlock once it's confirmed.")
                    .font(.manrope(12.5, .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(L.muted)
            }

            BigCTA(
                title: ctaTitle,
                kind: .primary
            ) {
                Task { await buy() }
            }
            .disabled(selectedProduct == nil || store.purchasing)
            .opacity(selectedProduct == nil || store.purchasing ? 0.5 : 1)

            Text("Recurring billing. Cancel anytime in the App Store.")
                .font(.mono(10))
                .tracking(0.4)
                .foregroundStyle(L.muted2)
        }
        .padding(.horizontal, L.S.pad)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(L.paper)
    }

    private var ctaTitle: String {
        if store.purchasing { return "Please wait…" }
        guard let p = selectedProduct else { return "Continue" }
        if let offer = p.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "Start free trial"
        }
        return "Continue"
    }

    // MARK: - Helpers

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedID }
    }

    /// Default the selection to the first (top / best-value) available plan
    /// whenever the catalog changes and nothing valid is selected.
    private func syncSelection() {
        let ids = store.products.map(\.id)
        if selectedID == nil || !(ids.contains(selectedID ?? "")) {
            selectedID = ids.first
        }
    }

    private func badge(for product: Product) -> String? {
        if product.id == StoreService.ProKey.yearly.rawValue { return "Best value" }
        return nil
    }

    private func buy() async {
        guard let product = selectedProduct else { return }
        error = nil
        pendingNote = false
        do {
            switch try await store.purchase(product) {
            case .success:  onClose()
            case .pending:  pendingNote = true
            case .cancelled: break
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore() async {
        error = nil
        pendingNote = false
        do {
            try await store.restore()
            if !store.isPro {
                error = "No active subscription found to restore."
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let product: Product
    let badge: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.manrope(15.5, .heavy))
                            .kerning(-0.2)
                            .foregroundStyle(L.ink)
                        if let badge {
                            Text(badge.uppercased())
                                .font(.manrope(9.5, .heavy))
                                .tracking(0.8)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(L.brand, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.manrope(12.5, .semibold))
                        .foregroundStyle(L.muted)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.manrope(16, .heavy))
                    .foregroundStyle(L.ink)
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.clear : L.muted.opacity(0.4), lineWidth: 1.5)
                    if selected {
                        Circle().fill(L.brand)
                        LSymbol(key: "check", size: 11, weight: .heavy).foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.lg, style: .continuous)
                    .strokeBorder(selected ? L.brand : L.hairline, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(_PayShadow())
        .tapPress()
    }

    /// Human-readable plan name from the subscription period.
    private var title: String {
        guard let period = product.subscription?.subscriptionPeriod else { return product.displayName }
        switch period.unit {
        case .year:  return period.value == 1 ? "Yearly" : "\(period.value) years"
        case .month: return period.value == 1 ? "Monthly" : "\(period.value) months"
        case .week:  return period.value == 1 ? "Weekly" : "\(period.value) weeks"
        case .day:   return period.value == 1 ? "Daily" : "\(period.value) days"
        @unknown default: return product.displayName
        }
    }

    /// Trial / billing-cadence subtitle.
    private var subtitle: String {
        if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            return "\(offer.period.value) \(unitName(offer.period)) free, then \(product.displayPrice)"
        }
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        return "Billed every \(period.value == 1 ? unitName(period) : "\(period.value) \(unitName(period))s")"
    }

    private func unitName(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .year:  return "year"
        case .month: return "month"
        case .week:  return "week"
        case .day:   return "day"
        @unknown default: return "period"
        }
    }
}

private struct _PayShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

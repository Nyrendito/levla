import Foundation
import StoreKit
import Observation

/// StoreKit 2 subscription store for Levla Pro.
///
/// ## Why this loads products the way it does
///
/// The paywall used to go blank whenever **one** of the subscription
/// products wasn't fully "Ready to Submit" / approved in App Store Connect.
/// That's because App Store Connect only returns *approved & available*
/// products from `Product.products(for:)` — if you ask for two IDs and only
/// one has cleared review, StoreKit hands back an **array of one** (and it
/// isn't an error). Any paywall that gates on "did I get *all* the products
/// I asked for?" (e.g. `guard products.count == ids.count`) will therefore
/// show nothing at all until *every* product is live.
///
/// The fix is to treat the request as **best-effort**: render whatever came
/// back, in our preferred display order, and only fall back to an error /
/// retry state when *zero* products load. A product that's still pending
/// review simply doesn't appear yet; the others load and are purchasable.
@MainActor
@Observable
final class StoreService {

    // MARK: - Product catalog

    /// The subscription products we offer, in the order we want to display
    /// them on the paywall. IDs must match the auto-renewable subscriptions
    /// configured in App Store Connect (bundle id `com.nyrendito.levla`).
    ///
    /// Adding a new tier here is safe: if it isn't approved yet it just won't
    /// show up until App Store Connect starts returning it — the rest of the
    /// paywall keeps working.
    enum ProKey: String, CaseIterable {
        case yearly  = "com.nyrendito.levla.pro.yearly"
        case monthly = "com.nyrendito.levla.pro.monthly"
    }

    /// All the IDs we ask App Store Connect for.
    static let productIDs: [String] = ProKey.allCases.map(\.rawValue)

    /// The set of IDs that grant Pro. Kept separate from `productIDs` so a
    /// consumable / non-subscription product could be added later without
    /// accidentally granting entitlement.
    private static let proProductIDs: Set<String> = Set(productIDs)

    // MARK: - Observable state

    /// Loaded, purchasable products — already sorted into display order.
    /// May contain *fewer* entries than `productIDs` when some products are
    /// still pending review; that is expected, not an error.
    private(set) var products: [Product] = []

    /// Product IDs we requested but App Store Connect didn't return (usually
    /// "not yet approved" or "removed"). Surfaced only for logging / debug.
    private(set) var unavailableProductIDs: [String] = []

    /// True once the user holds an active Pro entitlement.
    private(set) var isPro: Bool = false

    enum LoadState: Equatable {
        case idle
        case loading
        /// At least one product loaded. `partial` is true when some requested
        /// products didn't come back (still pending on ASC) — the paywall is
        /// fully usable regardless.
        case loaded(partial: Bool)
        /// Zero products loaded — network failure, or nothing approved yet.
        case failed(String)
    }
    private(set) var loadState: LoadState = .idle

    /// Set while a purchase / restore is in flight so the UI can disable CTAs.
    private(set) var purchasing: Bool = false

    private var updatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    init() {
        // Start listening for transactions BEFORE any purchase so we never
        // miss an Ask-to-Buy approval, a Family Sharing grant, or a renewal
        // that lands while the app is backgrounded.
        updatesTask = listenForTransactions()
    }

    deinit { updatesTask?.cancel() }

    /// Kick off the initial product load + entitlement refresh. Safe to call
    /// on every app launch and again from the paywall's `.task`.
    func bootstrap() async {
        async let _ = loadProducts()
        await refreshEntitlements()
    }

    // MARK: - Product loading (the actual fix)

    /// Fetch products from App Store Connect. Renders whatever is available;
    /// a missing product (pending review) is *not* treated as failure.
    func loadProducts() async {
        loadState = .loading
        do {
            let fetched = try await Product.products(for: Self.productIDs)

            // Sort into our preferred display order regardless of the order
            // StoreKit returns them in.
            let order = Self.productIDs
            let sorted = fetched.sorted {
                (order.firstIndex(of: $0.id) ?? .max) < (order.firstIndex(of: $1.id) ?? .max)
            }

            let returnedIDs = Set(fetched.map(\.id))
            let missing = Self.productIDs.filter { !returnedIDs.contains($0) }

            self.products = sorted
            self.unavailableProductIDs = missing

            if sorted.isEmpty {
                // Nothing came back at all. This is the only real failure —
                // either the network is down or no product has cleared review.
                self.loadState = .failed("No subscriptions are available right now.")
            } else {
                if !missing.isEmpty {
                    print("ℹ️ StoreService: loaded \(sorted.count)/\(Self.productIDs.count) products. " +
                          "Pending / unavailable on ASC: \(missing.joined(separator: ", "))")
                }
                self.loadState = .loaded(partial: !missing.isEmpty)
            }
        } catch {
            // A thrown error here is a genuine load failure (e.g. no network),
            // distinct from "some products aren't approved yet".
            print("⚠️ StoreService: product load failed — \(error.localizedDescription)")
            self.products = []
            self.loadState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Purchase

    enum PurchaseOutcome { case success, pending, cancelled }

    /// Purchase a subscription. Returns the coarse outcome so the paywall can
    /// dismiss on success, show an "Ask to Buy pending" note, or do nothing on
    /// cancel. Throws only on a real StoreKit error.
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        purchasing = true
        defer { purchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
            return .success
        case .pending:
            // Ask-to-Buy / SCA — entitlement will arrive later via the
            // transaction listener.
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    /// Restore purchases. `AppStore.sync()` forces a receipt refresh; the
    /// entitlement recompute below is what actually flips `isPro`.
    func restore() async throws {
        purchasing = true
        defer { purchasing = false }
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Recompute `isPro` from the current entitlements. An entitlement counts
    /// only if it's for one of our Pro products and isn't revoked.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.proProductIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                active = true
            }
        }
        self.isPro = active
    }

    // MARK: - Transaction listener

    /// Long-lived listener for transactions that happen outside an explicit
    /// `purchase()` call — renewals, Ask-to-Buy approvals, Family Sharing,
    /// refunds/revocations, and purchases made on another device.
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                do {
                    let transaction = try await self.checkVerified(update)
                    await self.refreshEntitlements()
                    await transaction.finish()
                } catch {
                    print("⚠️ StoreService: unverified transaction update — \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Verification

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

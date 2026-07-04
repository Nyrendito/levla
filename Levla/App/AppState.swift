import SwiftUI
import Observation

/// Top-level app state container — owns the service singletons and
/// surfaces the currently-selected tab + any modal sheet state.
@MainActor
@Observable
final class AppState {
    let auth = AuthService()
    let profileService = ProfileService()
    let fridge = FridgeService()
    let shopping = ShoppingService()
    let recipes = RecipeService()
    let cooked = CookedLogService()
    let weightLog = WeightLogService()
    let water = WaterLogService()
    let store = StoreService()

    var selectedTab: MainTab = .home
    var presentingScan: ScanKind? = nil
    var presentingProfile: Bool = false
    var presentingLogMeal: Bool = false
    var presentingShopping: Bool = false
    var presentingPaywall: Bool = false

    /// True only when we have a confirmed signed-in user whose profile is
    /// known to NOT be onboarded yet. (`nil` profile is fine — we just haven't
    /// loaded it; we don't want to flash the onboarding screen.)
    var needsOnboarding: Bool {
        guard auth.currentUserId != nil else { return false }
        guard let p = profileService.profile else { return false }
        return !p.onboarded
    }

    /// The active profile — prefer ProfileService's row, fall back to whatever
    /// AuthService loaded at bootstrap, so the UI never flickers blank.
    var currentProfile: Profile? {
        profileService.profile ?? auth.profile
    }

    /// Once the user is signed in we hydrate the services that depend on a userId.
    func hydrate() async {
        // Load subscription products + entitlements up front so the paywall
        // opens instantly and gated features know Pro status on launch. Runs
        // independently of auth — StoreKit is tied to the Apple ID, not our
        // account.
        Task { await store.bootstrap() }

        await auth.bootstrap()
        if let uid = auth.currentUserId {
            async let p: Void  = profileService.reload(userId: uid)
            async let f: Void  = fridge.reload(userId: uid)
            async let s: Void  = shopping.reload(userId: uid)
            async let c: Void  = cooked.reloadToday(userId: uid)
            async let ch: Void = cooked.reloadHistory(userId: uid)
            async let w: Void  = weightLog.reload(userId: uid)
            _ = await (p, f, s, c, ch, w)
            await recipes.reload(for: fridge.items, profile: currentProfile)
        }
    }

    func refreshForUser() async {
        guard let uid = auth.currentUserId else { return }
        async let p: Void  = profileService.reload(userId: uid)
        async let f: Void  = fridge.reload(userId: uid)
        async let s: Void  = shopping.reload(userId: uid)
        async let c: Void  = cooked.reloadToday(userId: uid)
        async let ch: Void = cooked.reloadHistory(userId: uid)
        async let w: Void  = weightLog.reload(userId: uid)
        _ = await (p, f, s, c, ch, w)
        await recipes.reload(for: fridge.items, profile: currentProfile)
    }

    /// Called after a scan adds items — refresh shopping & recipe suggestions
    /// since both depend on the current fridge.
    func refreshAfterFridgeChange() async {
        await recipes.reload(for: fridge.items, profile: currentProfile)
    }
}

enum MainTab: Hashable {
    case home, fridge, cook, progress
}

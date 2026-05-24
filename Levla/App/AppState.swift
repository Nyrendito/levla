import SwiftUI
import Observation

/// Top-level app state container — owns the service singletons and
/// surfaces the currently-selected tab + any modal sheet state.
@MainActor
@Observable
final class AppState {
    let auth = AuthService()
    let fridge = FridgeService()
    let shopping = ShoppingService()
    let recipes = RecipeService()
    let cooked = CookedLogService()

    var selectedTab: MainTab = .home
    var presentingScan: ScanKind? = nil

    /// Once the user is signed in we hydrate the services that depend on a userId.
    func hydrate() async {
        await auth.bootstrap()
        if let uid = auth.currentUserId {
            async let f: Void = fridge.reload(userId: uid)
            async let s: Void = shopping.reload(userId: uid)
            async let c: Void = cooked.reloadToday(userId: uid)
            _ = await (f, s, c)
            await recipes.reload(for: fridge.items)
        }
    }

    func refreshForUser() async {
        guard let uid = auth.currentUserId else { return }
        async let f: Void = fridge.reload(userId: uid)
        async let s: Void = shopping.reload(userId: uid)
        async let c: Void = cooked.reloadToday(userId: uid)
        _ = await (f, s, c)
        await recipes.reload(for: fridge.items)
    }

    /// Called after a scan adds items — refresh shopping & recipe suggestions
    /// since both depend on the current fridge.
    func refreshAfterFridgeChange() async {
        await recipes.reload(for: fridge.items)
    }
}

enum MainTab: Hashable {
    case home, fridge, cook, list
}

import SwiftUI

@main
struct LevlaApp: App {
    @State private var appState = AppState()
    @State private var didBoot = false
    /// Drives the day-rollover refresh — bumped whenever the user crosses
    /// midnight (via `.NSCalendarDayChanged` or via foregrounding the app
    /// on a new calendar day). Any view that reads `app.cooked` re-evaluates.
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
                .task {
                    if !didBoot {
                        didBoot = true
                        await appState.hydrate()
                    }
                }
                // Foreground refresh: if the user backgrounded the app
                // last night and reopens it the next morning, the cached
                // todayEntries are from yesterday — refresh on .active.
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await refreshIfDayChanged() }
                    }
                }
                // In-app rollover: the system posts NSCalendarDayChanged
                // exactly when midnight passes (or the timezone changes).
                .onReceive(NotificationCenter.default
                    .publisher(for: .NSCalendarDayChanged)
                ) { _ in
                    Task { await refreshIfDayChanged() }
                }
        }
    }

    /// Refresh today's macro totals if the local calendar day has rolled
    /// over since they were last loaded. No-op otherwise.
    @MainActor
    private func refreshIfDayChanged() async {
        guard let uid = appState.auth.currentUserId else { return }
        await appState.cooked.refreshIfDayChanged(userId: uid)
    }
}

/// Switches between auth, onboarding, and main app based on AuthService +
/// profile state.
struct RootView: View {
    @Environment(AppState.self) private var app: AppState

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            switch app.auth.state {
            case .unknown:
                ProgressView().tint(L.ink)
            case .signedOut:
                AuthView()
            case .signedIn:
                if app.needsOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.auth.state)
        .animation(.easeInOut(duration: 0.25), value: app.profileService.profile?.onboarded)
    }
}

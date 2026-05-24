import SwiftUI

@main
struct LevlaApp: App {
    @State private var appState = AppState()
    @State private var didBoot = false

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
        }
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

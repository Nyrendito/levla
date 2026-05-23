import Foundation
import Supabase
import Auth
import AuthenticationServices

/// Auth state — driven by Supabase auth (when configured) or a local mock.
@MainActor
@Observable
final class AuthService {
    enum AuthState: Equatable {
        case unknown
        case signedOut
        case signedIn(userId: UUID, email: String?)
    }

    private(set) var state: AuthState = .unknown
    private(set) var profile: Profile?
    private(set) var lastError: String?

    private let supabase = LevlaSupabase.shared

    var currentUserId: UUID? {
        if case .signedIn(let id, _) = state { return id }
        return nil
    }

    var isOfflineMode: Bool { supabase.isOffline }

    /// On boot we either restore a Supabase session or sign the user in
    /// to the offline demo profile.
    func bootstrap() async {
        if supabase.isOffline {
            // Stable demo user id so the offline DB has a stable owner.
            let demoId = UUID(uuidString: "DEADBEEF-0000-0000-0000-000000000001")!
            state = .signedIn(userId: demoId, email: "demo@levla.app")
            profile = Profile(id: demoId, displayName: "Eva", streakDays: 5, fridgeScore: 8)
            return
        }

        // `auth.session` throws when there's no session OR when the stored
        // session is invalid (e.g. a stale "pending-confirmation" user). In
        // either case we want the user back on the welcome screen so they
        // get a fresh, real, signed-in session next time.
        let session = try? await supabase.client?.auth.session
        if let session, !session.accessToken.isEmpty {
            let user = session.user
            state = .signedIn(userId: user.id, email: user.email)
            try? await loadProfile()
        } else {
            // Wipe any half-broken persisted state so the next sign-in starts clean.
            try? await supabase.client?.auth.signOut()
            state = .signedOut
        }
    }

    /// True iff there's a real session with a non-empty access token.
    /// Backend calls should bail out early if this is false — saves a round
    /// trip and surfaces a clear error to the UI.
    func hasActiveSession() async -> Bool {
        guard let client = supabase.client else { return false }
        if let session = try? await client.auth.session, !session.accessToken.isEmpty {
            return true
        }
        return false
    }

    func signUp(email: String, password: String, displayName: String) async throws {
        guard let client = supabase.client else {
            // Offline mode — succeed silently.
            return
        }
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["display_name": .string(displayName)]
        )
        let user = response.user

        // If Supabase requires email confirmation, signUp returns a user with
        // no active session — surface that to the UI instead of pretending
        // they're logged in (which would 401 on every backend call).
        do {
            _ = try await client.auth.session
            state = .signedIn(userId: user.id, email: user.email)
            try? await loadProfile()
        } catch {
            throw AuthError.emailConfirmationRequired
        }
    }

    func signIn(email: String, password: String) async throws {
        guard let client = supabase.client else { return }
        let session = try await client.auth.signIn(email: email, password: password)
        let user = session.user
        state = .signedIn(userId: user.id, email: user.email)
        try? await loadProfile()
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        guard let client = supabase.client else { return }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        let user = session.user
        state = .signedIn(userId: user.id, email: user.email)
        try? await loadProfile()
    }

    /// Sign in via Supabase's hosted OAuth flow + ASWebAuthenticationSession.
    /// Works for any Supabase-supported provider (google, apple, github, …).
    /// Needs the provider enabled & configured in Supabase Auth → Providers.
    func signInWithOAuth(provider: OAuthProvider) async throws {
        guard let client = supabase.client else { return }

        let redirectURL = URL(string: "levla://login-callback")!
        let session = try await client.auth.signInWithOAuth(
            provider: provider.supabaseProvider,
            redirectTo: redirectURL,
            launchFlow: { url in
                try await OAuthPresenter.shared.openCallback(url: url, callbackScheme: "levla")
            }
        )
        let user = session.user
        state = .signedIn(userId: user.id, email: user.email)
        try? await loadProfile()
    }

    func signOut() async {
        if let client = supabase.client {
            try? await client.auth.signOut()
        }
        state = .signedOut
        profile = nil
    }

    func loadProfile() async throws {
        guard case .signedIn(let id, _) = state, let client = supabase.client else { return }
        let row: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        profile = row
    }
}

enum AuthError: LocalizedError {
    case emailConfirmationRequired
    var errorDescription: String? {
        switch self {
        case .emailConfirmationRequired:
            return "Check your inbox — confirm the email we just sent, then sign in."
        }
    }
}

/// The OAuth providers exposed in the welcome screen. Mapped to Supabase
/// `Provider` at the call site.
enum OAuthProvider {
    case google, apple

    var supabaseProvider: Provider {
        switch self {
        case .google: return .google
        case .apple:  return .apple
        }
    }

    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple:  return "Apple"
        }
    }
}

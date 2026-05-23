import Foundation
import Supabase
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

        do {
            let session = try await supabase.client?.auth.session
            if let session {
                let user = session.user
                state = .signedIn(userId: user.id, email: user.email)
                try? await loadProfile()
            } else {
                state = .signedOut
            }
        } catch {
            state = .signedOut
        }
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
        state = .signedIn(userId: user.id, email: user.email)
        try? await loadProfile()
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

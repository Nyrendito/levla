import AuthenticationServices
import UIKit

/// Bridges `ASWebAuthenticationSession` to async/await, and supplies a
/// presentation anchor pointing at the active key window.
///
/// Used by `AuthService.signInWithOAuth(...)` to drive Sign in with Google /
/// Sign in with Apple via Supabase's hosted OAuth flow.
@MainActor
final class OAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthPresenter()

    func openCallback(url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let callbackURL else {
                    cont.resume(throwing: OAuthError.cancelled)
                    return
                }
                cont.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            // Keep the user logged in if they had a previous Google/Apple session
            // in Safari — much nicer UX than forcing a fresh login every time.
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}

enum OAuthError: LocalizedError {
    case cancelled
    var errorDescription: String? {
        switch self {
        case .cancelled: return "Sign-in was cancelled."
        }
    }
}

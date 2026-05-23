import SwiftUI
import AuthenticationServices
import CryptoKit

/// Welcome screen — "Know what's in your fridge." mirrors the design's
/// V2 onboarding welcome: phone-in-phone hero + big headline + black CTA
/// + sign-in link + EN language pill.
struct AuthView: View {
    @Environment(AppState.self) private var app

    @State private var mode: Mode = .welcome
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var appleNonce: String?
    @State private var error: String?
    @State private var loading = false

    enum Mode { case welcome, signIn, signUp }

    /// Flip to true once the project has a paid Apple Developer team + the
    /// "Sign in with Apple" capability re-added in Xcode.
    static let enableAppleSignIn = false

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            switch mode {
            case .welcome:
                welcome
            case .signIn:
                form(isSignUp: false)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            case .signUp:
                form(isSignUp: true)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: mode)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {} label: {
                    HStack(spacing: 6) {
                        Text("🇬🇧").font(.system(size: 14))
                        Text("EN").font(.manrope(13, .heavy))
                        LSymbol(key: "chevronDown", size: 11, weight: .bold)
                    }
                    .foregroundStyle(L.ink)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.white, in: Capsule())
                }
                .modifier(_Soft())
            }
            .padding(.horizontal, L.S.pad)
            .padding(.top, 8)

            Spacer(minLength: 12)

            // phone-in-phone hero
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(L.ink)
                    .frame(width: 240, height: 380)
                    .shadow(color: L.ink.opacity(0.30), radius: 30, x: 0, y: 18)

                VStack(spacing: 10) {
                    Text("SCANNING")
                        .font(.mono(10))
                        .tracking(1.2)
                        .foregroundStyle(L.cream.opacity(0.55))
                        .padding(.top, 36)
                    HStack(spacing: 8) {
                        chip(L.mint, label: "Spinach")
                        chip(L.pop, label: "Tomatoes")
                    }
                    chip(L.sun, label: "Whole milk")

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(L.cream.opacity(0.08))
                            .frame(width: 180, height: 200)
                        VStack(spacing: 8) {
                            HStack(spacing: 10) {
                                Circle().fill(L.mint).frame(width: 22, height: 22)
                                Circle().fill(L.sun).frame(width: 24, height: 24)
                                Circle().fill(L.pop).frame(width: 20, height: 20)
                                Circle().fill(L.cream).frame(width: 18, height: 18)
                            }
                            HStack(spacing: 10) {
                                Circle().fill(L.pop).frame(width: 18, height: 18)
                                Circle().fill(L.mint).frame(width: 24, height: 24)
                                Circle().fill(L.cream).frame(width: 22, height: 22)
                            }
                            HStack(spacing: 10) {
                                Circle().fill(L.sun).frame(width: 20, height: 20)
                                Circle().fill(L.pop).frame(width: 18, height: 18)
                                Circle().fill(L.mint).frame(width: 22, height: 22)
                            }
                        }
                    }
                    .padding(.top, 6)
                    Spacer()
                }
                .frame(width: 240, height: 380)
                .clipped()
            }

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Know what's\nin your fridge.")
                    .font(.manrope(40, .heavy))
                    .kerning(-1.4)
                    .lineSpacing(2)
                    .foregroundStyle(L.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Scan once. Cook with what you already have.")
                    .font(.manrope(15, .semibold))
                    .foregroundStyle(L.ink.opacity(0.55))
            }
            .padding(.horizontal, L.S.pad)
            .padding(.top, 10)

            VStack(spacing: 10) {
                AppleSignInButton {
                    runOAuth(.apple)
                }
                GoogleSignInButton {
                    runOAuth(.google)
                }
                BigCTA(title: "Continue with email", icon: nil, kind: .light) {
                    withAnimation { mode = .signUp }
                }
            }
            .padding(.horizontal, L.S.pad)
            .padding(.top, 22)
            .opacity(loading ? 0.5 : 1)
            .disabled(loading)

            if let error {
                Text(error)
                    .font(.manrope(12.5, .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(L.rose)
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 10)
            }

            Button {
                withAnimation { mode = .signIn }
            } label: {
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .foregroundStyle(L.ink.opacity(0.6))
                    Text("Sign in")
                        .foregroundStyle(L.ink)
                }
                .font(.manrope(14, .heavy))
                .kerning(-0.1)
            }
            .padding(.top, 14)
            .padding(.bottom, 28)
            .buttonStyle(.plain)
        }
    }

    private func runOAuth(_ provider: OAuthProvider) {
        guard !loading else { return }
        if app.auth.isOfflineMode {
            error = "Connect Supabase first (see README) to use \(provider.displayName) sign-in."
            return
        }
        loading = true
        error = nil
        Task {
            do {
                try await app.auth.signInWithOAuth(provider: provider)
                await app.refreshForUser()
            } catch {
                if case OAuthError.cancelled = error {
                    // user backed out — no need to surface anything
                } else {
                    self.error = error.localizedDescription
                }
            }
            loading = false
        }
    }

    private func chip(_ color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.manrope(11, .heavy))
                .foregroundStyle(L.cream)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(L.cream.opacity(0.10), in: Capsule())
    }

    // MARK: - Sign in / Sign up form

    private func form(isSignUp: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                Button { withAnimation { mode = .welcome } } label: {
                    LSymbol(key: "chevronL", size: 18, weight: .semibold)
                        .foregroundStyle(L.ink)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .modifier(_Soft())
                Spacer()
            }
            .padding(.horizontal, L.S.pad)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 8) {
                Text(isSignUp ? "Welcome to Levla." : "Welcome back.")
                    .font(.manrope(36, .heavy))
                    .kerning(-1.2)
                    .foregroundStyle(L.ink)
                Text(isSignUp ? "Create an account in a few seconds." : "Sign in to your fridge.")
                    .font(.manrope(15, .semibold))
                    .foregroundStyle(L.ink.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, L.S.pad)

            VStack(spacing: 12) {
                if isSignUp {
                    field("Name", text: $displayName, content: .name, secure: false)
                }
                field("Email", text: $email, content: .emailAddress, secure: false)
                field("Password", text: $password, content: .password, secure: true)

                if let error {
                    Text(error)
                        .font(.manrope(13, .semibold))
                        .foregroundStyle(L.rose)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                BigCTA(title: isSignUp ? "Create account" : "Sign in", kind: .primary) {
                    submit(isSignUp: isSignUp)
                }
                .disabled(loading)

                if app.auth.isOfflineMode {
                    Text("Running in offline demo mode.\nConnect Supabase in Info.plist to enable real accounts.")
                        .multilineTextAlignment(.center)
                        .font(.mono(10.5))
                        .tracking(0.6)
                        .foregroundStyle(L.ink.opacity(0.4))
                        .padding(.top, 4)
                }

                // Sign in with Apple requires the Apple Developer Program
                // (paid) — gated behind a build flag so the code stays here.
                // Flip ENABLE_APPLE_SIGN_IN to true once you have a paid team
                // and re-add the entitlement / capability in Xcode.
                if Self.enableAppleSignIn {
                    SignInWithAppleButton(.continue) { request in
                        let nonce = randomNonce()
                        self.appleNonce = nonce
                        request.requestedScopes = [.email, .fullName]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleResult(result)
                    }
                    .frame(height: L.btnHeight)
                    .signInWithAppleButtonStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
                }

                Button {
                    withAnimation { mode = isSignUp ? .signIn : .signUp }
                } label: {
                    HStack(spacing: 4) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundStyle(L.ink.opacity(0.6))
                        Text(isSignUp ? "Sign in" : "Sign up")
                            .foregroundStyle(L.ink)
                    }
                    .font(.manrope(14, .heavy))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(.horizontal, L.S.pad)
            Spacer()
        }
    }

    private func field(_ label: String, text: Binding<String>, content: UITextContentType, secure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.manrope(11, .heavy))
                .tracking(0.6)
                .foregroundStyle(L.ink.opacity(0.5))
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .textInputAutocapitalization(content == .name ? .words : .never)
                        .autocorrectionDisabled(content != .name)
                        .keyboardType(content == .emailAddress ? .emailAddress : .default)
                }
            }
            .textContentType(content)
            .font(.manrope(16, .semibold))
            .foregroundStyle(L.ink)
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .modifier(_Soft())
        }
    }

    private func submit(isSignUp: Bool) {
        guard !loading else { return }
        error = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        if app.auth.isOfflineMode {
            // In offline mode there's no real account — RootView already
            // transitions to MainTabView once `state == .signedIn`. The
            // `bootstrap()` call set that on launch, so this branch is a no-op.
            return
        }

        guard trimmedEmail.contains("@"), password.count >= 6 else {
            error = "Enter a valid email and a 6+ character password."
            return
        }

        loading = true
        Task {
            do {
                if isSignUp {
                    let name = displayName.isEmpty ? String(trimmedEmail.split(separator: "@").first ?? "Eva") : displayName
                    try await app.auth.signUp(email: trimmedEmail, password: password, displayName: name)
                } else {
                    try await app.auth.signIn(email: trimmedEmail, password: password)
                }
                await app.refreshForUser()
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce
            else { return }
            Task {
                do {
                    try await app.auth.signInWithApple(idToken: token, nonce: nonce)
                    await app.refreshForUser()
                } catch {
                    self.error = error.localizedDescription
                }
            }
        case .failure(let err):
            // user cancel is .canceled — silently ignore
            if (err as NSError).code != ASAuthorizationError.canceled.rawValue {
                self.error = err.localizedDescription
            }
        }
    }
}

private struct _Soft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

// MARK: - Apple Sign-in nonce helpers

private func randomNonce(length: Int = 32) -> String {
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        var random: UInt8 = 0
        _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
        if random < charset.count {
            result.append(charset[Int(random)])
            remaining -= 1
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - Apple / Google branded buttons

private struct AppleSignInButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(L.cream)
                Text("Continue with Apple")
                    .font(.manrope(17, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.cream)
            }
            .frame(maxWidth: .infinity)
            .frame(height: L.btnHeight)
            .background(L.ink, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(_OAuthShadow())
        .tapPress()
    }
}

private struct GoogleSignInButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                GoogleGMark().frame(width: 22, height: 22)
                Text("Continue with Google")
                    .font(.manrope(17, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: L.btnHeight)
            .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .stroke(L.ink.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(_OAuthShadow())
        .tapPress()
    }
}

/// Simplified Google "G" mark — four quadrant arcs in red / yellow / green / blue
/// plus the horizontal bar. Drawn at runtime so we don't ship any third-party logo.
private struct GoogleGMark: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let r = min(w, h) / 2
            let lineWidth = r * 0.42
            let outerRect = CGRect(x: (w - r * 2) / 2 + lineWidth / 2,
                                   y: (h - r * 2) / 2 + lineWidth / 2,
                                   width: r * 2 - lineWidth,
                                   height: r * 2 - lineWidth)

            // Quadrant arcs (Google's four brand colors)
            ctx.stroke(arc(in: outerRect, start: -90, end: 0),  with: .color(Color(red: 0.918, green: 0.263, blue: 0.208)), lineWidth: lineWidth)        // red (top)
            ctx.stroke(arc(in: outerRect, start: 0,   end: 90), with: .color(Color(red: 0.984, green: 0.737, blue: 0.020)), lineWidth: lineWidth)        // yellow (right)
            ctx.stroke(arc(in: outerRect, start: 90,  end: 180),with: .color(Color(red: 0.204, green: 0.659, blue: 0.325)), lineWidth: lineWidth)        // green (bottom)
            ctx.stroke(arc(in: outerRect, start: 180, end: 270),with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)), lineWidth: lineWidth)        // blue (left)

            // Inner notch on the right + horizontal bar (the "G" opening)
            let barHeight = lineWidth * 0.9
            let barY = h / 2 - barHeight / 2
            let barX = w / 2
            let barWidth = r - lineWidth * 0.4
            let barRect = CGRect(x: barX, y: barY, width: barWidth, height: barHeight)
            ctx.fill(Path(roundedRect: barRect, cornerRadius: barHeight / 2),
                     with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))

            // Clear out the right side so the "G" reads as open
            let notch = CGRect(x: w - lineWidth * 0.6, y: 0, width: lineWidth * 0.6, height: h / 2 - barHeight / 2)
            ctx.fill(Path(notch), with: .color(Color.white))
        }
    }

    private func arc(in rect: CGRect, start: Double, end: Double) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                     radius: rect.width / 2,
                     startAngle: .degrees(start),
                     endAngle: .degrees(end),
                     clockwise: false)
        }
    }
}

private struct _OAuthShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: L.ink.opacity(0.10), radius: 10, x: 0, y: 4)
    }
}

import Foundation
import Supabase

/// Reads & writes the user's profile row in Supabase. Kept separate from
/// `AuthService` so onboarding / settings can mutate fields without
/// touching the session.
@MainActor
@Observable
final class ProfileService {
    private(set) var profile: Profile?
    private(set) var isSaving = false
    private(set) var lastError: String?

    private let supabase = LevlaSupabase.shared

    /// Pull the latest profile row from Postgres. Fetches as array + first()
    /// so a fresh user with no row yet doesn't throw — we'll insert on the
    /// first save inside `OnboardingView`.
    func reload(userId: UUID) async {
        if supabase.isOffline {
            // Offline mode keeps whatever AuthService seeded.
            return
        }
        guard let client = supabase.client else { return }
        do {
            let rows: [Profile] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            profile = rows.first
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Upsert the entire row. Called from the onboarding flow + settings page.
    /// Onboarded=true is set automatically when the user finishes onboarding.
    func save(_ updated: Profile) async {
        isSaving = true
        defer { isSaving = false }

        if supabase.isOffline {
            profile = updated
            return
        }

        guard let client = supabase.client else { return }
        do {
            try await client
                .from("profiles")
                .upsert(updated, onConflict: "id")
                .execute()
            profile = updated
        } catch {
            lastError = String(describing: error)
        }
    }

    /// Mark the user as onboarded once the multi-step flow completes.
    func markOnboarded(userId: UUID) async {
        guard var p = profile else { return }
        p.onboarded = true
        await save(p)
    }
}

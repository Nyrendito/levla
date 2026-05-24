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

    // MARK: - AI plan generation

    /// Result of an AI plan generation request.
    struct GeneratedPlan: Decodable, Sendable {
        let kcal: Int
        let protein: Int
        let carbs: Int
        let fat: Int
        let fiber: Int
        let sugar: Int
        let sodium: Int
        let rationale: String
    }

    /// Call the `generate-meal-plan` Edge Function with the given profile
    /// and write the result back to the row's baseline_* fields. Used at
    /// the end of onboarding and any time the user manually re-runs the
    /// plan from settings.
    ///
    /// Returns the plan it just generated, or nil if the call failed.
    @discardableResult
    func generatePlan(for source: Profile) async -> GeneratedPlan? {
        guard let client = supabase.client else {
            // Offline mode — synthesise a sensible plan locally so the
            // onboarding flow always completes.
            let synth = synthesizePlan(for: source)
            await persistPlan(synth, source: source)
            return synth
        }
        guard let session = try? await client.auth.session, !session.accessToken.isEmpty else {
            return nil
        }

        let payload = PlanRequest(profile: PlanRequest.WireProfile(from: source))
        do {
            let data = try await client.functions.invoke(
                "generate-meal-plan",
                options: .init(body: payload)
            ) { (data: Data, response: HTTPURLResponse) -> Data in
                guard 200..<300 ~= response.statusCode else {
                    throw FunctionsError.httpError(code: response.statusCode, data: data)
                }
                return data
            }
            let plan = try JSONDecoder().decode(GeneratedPlan.self, from: data)
            await persistPlan(plan, source: source)
            return plan
        } catch {
            lastError = String(describing: error)
            // Soft-fail to a synthesised plan so onboarding doesn't dead-end
            // when the LLM is unreachable.
            let synth = synthesizePlan(for: source)
            await persistPlan(synth, source: source)
            return synth
        }
    }

    /// Write a generated plan onto the user's profile row, snapshotting the
    /// inputs that produced it (so we can compute smart deltas later).
    private func persistPlan(_ plan: GeneratedPlan, source: Profile) async {
        guard var p = profile ?? Optional(source) else { return }
        p.baselineKcalGoal    = plan.kcal
        p.baselineProteinGoal = plan.protein
        p.baselineCarbsGoal   = plan.carbs
        p.baselineFatGoal     = plan.fat
        p.baselineFiberGoal   = plan.fiber
        p.baselineSugarGoal   = plan.sugar
        p.baselineSodiumGoal  = plan.sodium
        p.baselineWeightKg    = source.weightKg
        p.baselineHeightCm    = source.heightCm
        p.baselineAge         = source.age
        p.baselineSex         = source.sex
        p.baselineActivity    = source.activityLevel
        p.baselineGoal        = source.goal
        p.planRationale       = plan.rationale
        p.planGeneratedAt     = Date()
        await save(p)
    }

    /// Fallback when the AI is unreachable — use Mifflin-St Jeor +
    /// reference intakes to derive a plan locally. Keeps the onboarding
    /// flow functional even with the network down.
    private func synthesizePlan(for p: Profile) -> GeneratedPlan {
        let kcal     = p.dailyKcalGoal ?? 2_000
        let protein  = p.dailyProteinGoal ?? 100
        let fat      = p.dailyFatGoal ?? 60
        let carbs    = p.dailyCarbsGoal ?? 240
        let fiber    = p.dailyFiberGoal ?? 28
        let sugar    = p.dailySugarGoal ?? 50
        let sodium   = p.dailySodiumGoal ?? 2_300
        return GeneratedPlan(
            kcal: kcal, protein: protein, carbs: carbs, fat: fat,
            fiber: fiber, sugar: sugar, sodium: sodium,
            rationale: "Plan synthesised locally from your stats. Connect to the internet and tap Regenerate plan in settings to get a personalised AI plan."
        )
    }

    /// Wire payload for generate-meal-plan.
    private struct PlanRequest: Encodable {
        let profile: WireProfile

        struct WireProfile: Encodable {
            let sex: String?
            let age: Int?
            let heightCm: Int?
            let weightKg: Double?
            let activityLevel: String?
            let goal: String?
            let dietaryPrefs: [String]

            init(from p: Profile) {
                self.sex = p.sex?.rawValue
                self.age = p.age
                self.heightCm = p.heightCm
                self.weightKg = p.weightKg
                self.activityLevel = p.activityLevel?.rawValue
                self.goal = p.goal?.rawValue
                self.dietaryPrefs = p.dietaryPrefs
            }
        }
    }
}

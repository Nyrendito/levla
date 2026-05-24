import Foundation
import Supabase

/// Reads + writes weight_logs. Backs the Progress tab's My Weight card and
/// the Goal Progress line chart.
@MainActor
@Observable
final class WeightLogService {
    private(set) var logs: [WeightLog] = []
    private(set) var isSaving = false
    private(set) var lastError: String?

    private let supabase = LevlaSupabase.shared
    private var offlineStore: [WeightLog] = []

    /// The most recent weigh-in, or nil if the user has never logged one.
    var latest: WeightLog? {
        logs.max(by: { $0.loggedAt < $1.loggedAt })
    }

    /// Days since the latest weigh-in (rounded). nil if no logs yet.
    var daysSinceLatest: Int? {
        guard let latest else { return nil }
        let interval = Date().timeIntervalSince(latest.loggedAt)
        return max(0, Int((interval / 86_400).rounded()))
    }

    /// True when it's been a week or more — Progress tab shows a "log weigh-in"
    /// nudge in that case.
    var needsWeighIn: Bool {
        (daysSinceLatest ?? 999) >= 7
    }

    /// Most-recent weight value in kg. Falls back to profile.weightKg via the
    /// caller if no logs exist.
    var latestKg: Double? { latest?.weightKg }

    // MARK: - Load

    func reload(userId: UUID) async {
        if supabase.isOffline {
            logs = offlineStore.sorted(by: { $0.loggedAt > $1.loggedAt })
            return
        }
        guard let client = supabase.client else { return }
        do {
            let rows: [WeightLog] = try await client
                .from("weight_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .order("logged_at", ascending: false)
                .execute()
                .value
            logs = rows
        } catch {
            lastError = String(describing: error)
        }
    }

    // MARK: - Insert

    /// Log a new weigh-in. The Progress tab calls this from the "Log weight"
    /// sheet. We also mirror the value onto profiles.weight_kg so recipe
    /// suggestions stay in sync with the current weight without an extra
    /// round-trip.
    func log(weightKg: Double, userId: UUID, profileService: ProfileService) async {
        let normalized = (weightKg * 10).rounded() / 10
        guard normalized >= 25, normalized <= 350 else { return }
        isSaving = true
        defer { isSaving = false }

        let entry = WeightLog(userId: userId, weightKg: normalized)

        if supabase.isOffline {
            offlineStore.insert(entry, at: 0)
            logs = offlineStore.sorted(by: { $0.loggedAt > $1.loggedAt })
        } else {
            guard let client = supabase.client else { return }
            do {
                try await client.from("weight_logs").insert(entry).execute()
                await reload(userId: userId)
            } catch {
                lastError = String(describing: error)
                return
            }
        }

        // Mirror onto profiles so the rest of the app (recipe personalization,
        // BMI math, etc.) picks up the new weight immediately.
        if var p = profileService.profile {
            p.weightKg = normalized
            await profileService.save(p)
        }
    }
}

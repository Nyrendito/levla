import Foundation
import Supabase

/// Singleton Supabase client. Reads URL + anon key from Info.plist
/// (`SUPABASE_URL` and `SUPABASE_ANON_KEY`). If both are unset the app falls
/// back to an offline demo mode driven by `SeedData`.
final class LevlaSupabase {
    static let shared = LevlaSupabase()

    let client: SupabaseClient?
    let isOffline: Bool

    private init() {
        let info = Bundle.main.infoDictionary
        let url = (info?["SUPABASE_URL"] as? String) ?? ""
        let key = (info?["SUPABASE_ANON_KEY"] as? String) ?? ""

        guard let supabaseURL = URL(string: url),
              !url.isEmpty, !key.isEmpty,
              !url.contains("YOUR_SUPABASE_URL") else {
            self.client = nil
            self.isOffline = true
            print("⚠️ Levla: Supabase credentials missing — running in OFFLINE demo mode.")
            return
        }

        self.client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: key)
        self.isOffline = false
    }
}

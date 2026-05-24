import Foundation
import Supabase

/// Asks the `gen-food-image` Edge Function for an image URL for a food key
/// or recipe. Caches resolved URLs in memory + on Supabase (server-side
/// cache table). Returns nil if image gen is unavailable (org not verified,
/// no OpenAI access, etc.) — the UI is expected to fall back to its
/// abstract illustration.
@MainActor
@Observable
final class ImageCacheService {
    static let shared = ImageCacheService()

    /// In-memory URL cache, keyed by "food:salmon" or "recipe:slug".
    private var memory: [String: URL] = [:]
    /// Coalesces concurrent requests for the same key.
    private var inFlight: [String: Task<URL?, Never>] = [:]

    private let supabase = LevlaSupabase.shared

    /// Returns a public image URL or nil. Cheap to call repeatedly — it
    /// coalesces in-flight requests and caches results.
    func imageURL(kind: ImageKind, key: String, title: String? = nil, uses: [String]? = nil) async -> URL? {
        let cacheKey = "\(kind.rawValue):\(key.lowercased())"
        if let cached = memory[cacheKey] { return cached }
        if let pending = inFlight[cacheKey] { return await pending.value }

        let task = Task<URL?, Never> { [weak self] in
            guard let self else { return nil }
            return await self.fetchURL(cacheKey: cacheKey, kind: kind, key: key, title: title, uses: uses)
        }
        inFlight[cacheKey] = task
        let url = await task.value
        inFlight[cacheKey] = nil
        if let url { memory[cacheKey] = url }
        return url
    }

    private func fetchURL(cacheKey: String, kind: ImageKind, key: String, title: String?, uses: [String]?) async -> URL? {
        guard let client = supabase.client else { return nil }
        // Need an active session — gen-food-image requires JWT.
        guard let session = try? await client.auth.session, !session.accessToken.isEmpty else { return nil }

        let payload = GenRequest(kind: kind.rawValue, key: key, title: title, uses: uses)

        do {
            // The closure-based invoke returns raw bytes. The shorter
            // `let data: Data = try await client.functions.invoke(...)`
            // form makes the SDK JSON-decode INTO Data, which expects a
            // base64 string — for a JSON body like {"url": "..."} that
            // throws a silent DecodingError that this catch swallows.
            let data = try await client.functions.invoke(
                "gen-food-image",
                options: .init(body: payload)
            ) { (data: Data, response: HTTPURLResponse) -> Data in
                guard 200..<300 ~= response.statusCode else {
                    throw FunctionsError.httpError(code: response.statusCode, data: data)
                }
                return data
            }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let urlString = root["url"] as? String,
                  let url = URL(string: urlString)
            else { return nil }
            return url
        } catch {
            return nil
        }
    }

    private struct GenRequest: Encodable {
        let kind: String
        let key: String
        let title: String?
        let uses: [String]?
    }
}

enum ImageKind: String {
    case food, recipe
}

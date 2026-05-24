import Foundation
import UIKit
import Supabase

/// Talks to the Supabase Edge Functions (`scan-fridge`, `scan-receipt`,
/// `lookup-barcode`). Falls back to local recognition when Supabase isn't
/// configured.
@MainActor
final class AIScanService {
    static let shared = AIScanService()
    private let supabase = LevlaSupabase.shared

    // MARK: - Public API

    /// Send a short fridge sweep clip to Gemini 2.5 Flash via the
    /// `scan-fridge` Edge Function. Returns parsed candidates ready for the
    /// verify list. This is the primary entry point for the iOS device path.
    ///
    /// One inline base64 video is a fraction of the token cost (and a much
    /// better signal — the model sees motion + context, not isolated stills)
    /// compared to the older `scanFridge(images:)` photo-grid path.
    func scanFridge(videoData: Data) async throws -> [ScanCandidate] {
        guard !videoData.isEmpty else { return [] }
        guard let client = supabase.client else { return [] }
        try await requireSession(client: client)

        let payload = FridgeVideoRequest(
            video: "data:video/mp4;base64,\(videoData.base64EncodedString())"
        )
        let decoded: ScanItemsResponse = try await client.functions.invoke(
            "scan-fridge",
            options: .init(body: payload)
        )
        return decoded.items.map { $0.toCandidate() }
    }

    /// Legacy multi-image path. Kept around as a fallback for offline /
    /// simulator (where AVCaptureMovieFileOutput can't run), but the real-
    /// device flow now uses `scanFridge(videoData:)`.
    func scanFridge(images: [UIImage]) async throws -> [ScanCandidate] {
        guard !images.isEmpty else { return [] }

        if supabase.isOffline {
            // Best-effort local fallback: classify the first image with Apple
            // Vision. Used in the simulator + when offline.
            return await VisionRecognizer.classify(images[0], kind: .fridge)
        }

        guard let client = supabase.client else { return [] }
        try await requireSession(client: client)

        let dataURIs = images.compactMap { uiImage -> String? in
            guard let jpeg = jpegResized(uiImage, maxEdge: 1024, quality: 0.7) else { return nil }
            return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }

        let payload = FridgeScanRequest(images: dataURIs)
        let decoded: ScanItemsResponse = try await client.functions.invoke(
            "scan-fridge",
            options: .init(body: payload)
        )
        return decoded.items.map { $0.toCandidate() }
    }

    /// Send already-OCR'd receipt text to GPT-4.1-mini via `scan-receipt`.
    func parseReceipt(text: String) async throws -> [ScanCandidate] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        if supabase.isOffline {
            // Local keyword-based parser as a fallback.
            return VisionRecognizer.parseReceiptLines(text.components(separatedBy: .newlines))
                .map { line in
                    ScanCandidate(
                        foodKey: line.foodKey == "default" ? "milk" : line.foodKey,
                        displayName: line.displayName,
                        qty: "1",
                        confidence: line.confidence,
                        category: defaultCategory(for: line.foodKey),
                        daysLeft: defaultDaysLeft(for: defaultCategory(for: line.foodKey))
                    )
                }
        }

        guard let client = supabase.client else { return [] }
        try await requireSession(client: client)

        let payload = ReceiptScanRequest(text: text)
        let decoded: ScanItemsResponse = try await client.functions.invoke(
            "scan-receipt",
            options: .init(body: payload)
        )
        return decoded.items.map { $0.toCandidate() }
    }

    /// Resolve a barcode to a Levla food item via `lookup-barcode`.
    func lookupBarcode(_ code: String) async throws -> ScanCandidate? {
        if supabase.isOffline {
            return ScanCandidate(
                foodKey: "milk",
                displayName: "Unknown product · \(code)",
                qty: "1",
                confidence: 0.40,
                category: .pantry,
                daysLeft: 30
            )
        }
        guard let client = supabase.client else { return nil }
        try await requireSession(client: client)

        let payload = BarcodeRequest(code: code)
        let decoded: BarcodeResponse = try await client.functions.invoke(
            "lookup-barcode",
            options: .init(body: payload)
        )
        return decoded.item?.toCandidate()
    }

    // MARK: - Session guard

    /// Bail out early with a clear error if there's no valid session JWT.
    /// Without this, the function would still be invoked, hit the verify_jwt
    /// gateway, and return 401 — which surfaces in iOS as the cryptic
    /// "non-2xx status code 401" string.
    private func requireSession(client: SupabaseClient) async throws {
        if let session = try? await client.auth.session, !session.accessToken.isEmpty {
            return
        }
        throw AIScanError.notSignedIn
    }

    // MARK: - Wire types

    private struct FridgeScanRequest: Encodable { let images: [String] }
    /// Video-first scan payload. `video` is a `data:video/mp4;base64,…` URI.
    private struct FridgeVideoRequest: Encodable { let video: String }
    private struct ReceiptScanRequest: Encodable { let text: String }
    private struct BarcodeRequest: Encodable { let code: String }

    private struct ScanItemsResponse: Decodable { let items: [LLMItem] }
    private struct BarcodeResponse: Decodable { let item: LLMItem? }

    /// Robust decoder for the LLM's per-item JSON.
    ///
    /// The model usually returns the schema we asked for, but in practice it
    /// occasionally returns:
    /// - `food_key` instead of `foodKey`
    /// - `days_left` instead of `daysLeft`
    /// - `confidence` / `daysLeft` as strings (`"0.92"`, `"7"`) instead of numbers
    /// - missing fields it deems "obvious"
    ///
    /// All of those used to throw `DecodingError`. Now we accept any of the
    /// common variants and fall back to safe defaults so a single weird item
    /// doesn't kill the whole scan.
    private struct LLMItem: Decodable {
        let name: String
        let foodKey: String
        let qty: String
        let category: String
        let daysLeft: Int
        let confidence: Double

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicKey.self)

            func string(_ keys: String...) -> String? {
                for k in keys {
                    let key = DynamicKey(stringValue: k)
                    if let v = try? c.decode(String.self, forKey: key) { return v }
                    if let n = try? c.decode(Double.self, forKey: key) { return String(n) }
                    if let n = try? c.decode(Int.self, forKey: key) { return String(n) }
                }
                return nil
            }
            func int(_ keys: String...) -> Int? {
                for k in keys {
                    let key = DynamicKey(stringValue: k)
                    if let v = try? c.decode(Int.self, forKey: key) { return v }
                    if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
                    if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
                }
                return nil
            }
            func double(_ keys: String...) -> Double? {
                for k in keys {
                    let key = DynamicKey(stringValue: k)
                    if let v = try? c.decode(Double.self, forKey: key) { return v }
                    if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
                    if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
                }
                return nil
            }

            name        = string("name", "title", "label") ?? "Unknown item"
            foodKey     = string("foodKey", "food_key", "key") ?? "milk"
            qty         = string("qty", "quantity", "amount", "size") ?? "1"
            category    = string("category", "cat", "type") ?? "Pantry"
            daysLeft    = int("daysLeft", "days_left", "expires_in_days", "expiry_days") ?? 7
            confidence  = double("confidence", "score", "certainty") ?? 0.7
        }

        func toCandidate() -> ScanCandidate {
            ScanCandidate(
                foodKey: normalizedFoodKey(foodKey),
                displayName: name,
                qty: qty,
                confidence: max(0, min(1, confidence)),
                category: FoodCategory(rawValue: category.capitalized) ?? .pantry,
                daysLeft: daysLeft
            )
        }
    }
}

/// JSON CodingKey that accepts any string — used by the defensive decoders
/// so they can probe several possible field names without listing them in
/// a static enum.
struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

enum AIScanError: LocalizedError {
    case notSignedIn
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in first — Levla needs a session to talk to the AI."
        }
    }
}

// MARK: - Helpers

private let knownFoodKeys: Set<String> = [
    // dairy
    "milk", "yogurt", "butter", "feta", "egg", "cream", "cheese",
    "mozzarella", "cheddar", "ricotta",
    // vegetables
    "spinach", "broccoli", "tomato", "carrot", "pepper", "lemon", "lime",
    "garlic", "ginger", "onion", "avocado", "potato", "sweet-potato",
    "mushroom", "cucumber", "zucchini", "lettuce", "cabbage",
    "corn", "peas", "asparagus", "celery", "leek", "eggplant", "beet", "radish",
    "pumpkin", "cauliflower", "green-beans", "kale", "arugula",
    // herbs
    "basil", "parsley", "cilantro", "dill", "thyme", "rosemary", "mint",
    // proteins
    "chicken", "salmon", "beef", "tuna", "shrimp", "tofu",
    "bacon", "ham", "sausage", "pork", "lamb", "turkey", "duck", "crab", "lobster",
    // pantry / grains
    "rice", "pasta", "oil", "bread", "pesto", "parmesan",
    "oats", "quinoa", "flour", "sugar", "honey", "jam",
    "chickpeas", "black-beans", "lentils", "almonds", "peanut-butter",
    // sauces
    "soy-sauce", "ketchup", "mustard", "mayo", "hummus", "olives", "pickles",
    // fruits
    "apple", "banana", "orange", "strawberry", "blueberry", "raspberry",
    "mango", "pineapple", "grape", "watermelon", "peach", "pear",
    "kiwi", "pomegranate",
    // drinks
    "wine", "water", "juice", "coffee", "tea",
]

private func normalizedFoodKey(_ raw: String) -> String {
    let lower = raw.lowercased().replacingOccurrences(of: " ", with: "-")
    if knownFoodKeys.contains(lower) { return lower }
    // If the LLM hallucinated a plural / variant, snap it to the closest match.
    for key in knownFoodKeys where lower.contains(key) { return key }
    return "milk"
}

private func defaultCategory(for foodKey: String) -> FoodCategory {
    switch foodKey {
    case "milk", "yogurt", "butter", "feta", "egg", "cream", "cheese",
         "mozzarella", "cheddar", "ricotta":
        return .dairy
    case "spinach", "broccoli", "tomato", "carrot", "pepper", "lemon", "lime",
         "garlic", "ginger", "onion", "avocado", "potato", "sweet-potato",
         "mushroom", "cucumber", "zucchini", "lettuce", "cabbage",
         "corn", "peas", "asparagus", "celery", "leek", "eggplant", "beet", "radish",
         "pumpkin", "cauliflower", "green-beans", "kale", "arugula",
         "basil", "parsley", "cilantro", "dill", "thyme", "rosemary", "mint",
         "apple", "banana", "orange", "strawberry", "blueberry", "raspberry",
         "mango", "pineapple", "grape", "watermelon", "peach", "pear",
         "kiwi", "pomegranate":
        return .vegetables
    case "chicken", "salmon", "beef", "tuna", "shrimp", "tofu",
         "bacon", "ham", "sausage", "pork", "lamb", "turkey", "duck", "crab", "lobster":
        return .meat
    case "rice", "pasta", "oil", "bread", "pesto", "parmesan",
         "oats", "quinoa", "flour", "sugar", "honey", "jam",
         "chickpeas", "black-beans", "lentils", "almonds", "peanut-butter",
         "soy-sauce", "ketchup", "mustard", "mayo", "hummus", "olives", "pickles":
        return .pantry
    case "wine", "water", "juice", "coffee", "tea":
        return .drinks
    default:
        return .pantry
    }
}

private func defaultDaysLeft(for category: FoodCategory) -> Int {
    switch category {
    case .dairy: return 7
    case .vegetables: return 6
    case .meat: return 2
    case .pantry: return 90
    case .drinks: return 30
    case .freezer: return 60
    }
}

/// Downscale + JPEG-encode in one step. Keeps payloads small enough that
/// posting 3-5 shelves to GPT-4o stays well under 5 MB.
private func jpegResized(_ image: UIImage, maxEdge: CGFloat, quality: CGFloat) -> Data? {
    let w = image.size.width, h = image.size.height
    let longEdge = max(w, h)
    let scale = longEdge > maxEdge ? maxEdge / longEdge : 1.0
    let newSize = CGSize(width: w * scale, height: h * scale)

    let renderer = UIGraphicsImageRenderer(size: newSize, format: {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1.0
        f.opaque = true
        return f
    }())
    let resized = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return resized.jpegData(compressionQuality: quality)
}

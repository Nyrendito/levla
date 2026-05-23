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

    /// Send N shelf photos to GPT-4o via the `scan-fridge` Edge Function.
    /// Returns the parsed candidates (already mapped to Levla's food keys).
    func scanFridge(images: [UIImage]) async throws -> [ScanCandidate] {
        guard !images.isEmpty else { return [] }

        if supabase.isOffline {
            // Best-effort local fallback: classify the first image with Apple
            // Vision. Not as good as GPT-4o, but the app stays usable.
            return await VisionRecognizer.classify(images[0], kind: .fridge)
        }

        guard let client = supabase.client else { return [] }

        let dataURIs = images.compactMap { uiImage -> String? in
            guard let jpeg = jpegResized(uiImage, maxEdge: 1024, quality: 0.7) else { return nil }
            return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
        }

        let payload = FridgeScanRequest(images: dataURIs)
        let data: Data = try await client.functions.invoke(
            "scan-fridge",
            options: .init(body: payload)
        )
        let decoded = try JSONDecoder().decode(ScanItemsResponse.self, from: data)
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

        let payload = ReceiptScanRequest(text: text)
        let data: Data = try await client.functions.invoke(
            "scan-receipt",
            options: .init(body: payload)
        )
        let decoded = try JSONDecoder().decode(ScanItemsResponse.self, from: data)
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

        let payload = BarcodeRequest(code: code)
        let data: Data = try await client.functions.invoke(
            "lookup-barcode",
            options: .init(body: payload)
        )
        let decoded = try JSONDecoder().decode(BarcodeResponse.self, from: data)
        return decoded.item?.toCandidate()
    }

    // MARK: - Wire types

    private struct FridgeScanRequest: Encodable { let images: [String] }
    private struct ReceiptScanRequest: Encodable { let text: String }
    private struct BarcodeRequest: Encodable { let code: String }

    private struct ScanItemsResponse: Decodable { let items: [LLMItem] }
    private struct BarcodeResponse: Decodable { let item: LLMItem? }

    private struct LLMItem: Decodable {
        let name: String
        let foodKey: String
        let qty: String
        let category: String
        let daysLeft: Int
        let confidence: Double

        func toCandidate() -> ScanCandidate {
            ScanCandidate(
                foodKey: normalizedFoodKey(foodKey),
                displayName: name,
                qty: qty,
                confidence: confidence,
                category: FoodCategory(rawValue: category) ?? .pantry,
                daysLeft: daysLeft
            )
        }
    }
}

// MARK: - Helpers

private let knownFoodKeys: Set<String> = [
    "milk","yogurt","butter","feta","egg","spinach","broccoli","tomato","carrot",
    "pepper","lemon","garlic","onion","avocado","chicken","salmon","beef","rice",
    "pasta","oil","bread","pesto","parmesan","wine","water",
]

private func normalizedFoodKey(_ raw: String) -> String {
    let lower = raw.lowercased()
    if knownFoodKeys.contains(lower) { return lower }
    // If the LLM hallucinated a plural / variant, snap it to the closest match.
    for key in knownFoodKeys where lower.contains(key) { return key }
    return "milk"
}

private func defaultCategory(for foodKey: String) -> FoodCategory {
    switch foodKey {
    case "milk", "yogurt", "butter", "feta", "egg": return .dairy
    case "spinach", "broccoli", "tomato", "carrot", "pepper", "lemon", "garlic", "onion", "avocado": return .vegetables
    case "chicken", "salmon", "beef": return .meat
    case "rice", "pasta", "oil", "bread", "pesto", "parmesan": return .pantry
    case "wine", "water": return .drinks
    default: return .pantry
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

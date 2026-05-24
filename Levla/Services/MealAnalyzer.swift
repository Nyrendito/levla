import Foundation
import UIKit
import Supabase

/// Result of analyzing a meal photo via the `analyze-meal` Edge Function.
/// Mirrors the JSON schema the function returns, with permissive decoding
/// to absorb the occasional snake_case / string-number drift.
struct AnalyzedMeal: Hashable, Sendable {
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var confidence: Double
    var ingredients: [AnalyzedIngredient]

    var displayConfidence: String {
        let pct = Int((confidence * 100).rounded())
        switch pct {
        case 85...: return "High confidence"
        case 60..<85: return "Pretty confident"
        default: return "Best guess"
        }
    }
}

struct AnalyzedIngredient: Hashable, Sendable, Identifiable {
    let id = UUID()
    var name: String
    var kcal: Int
    var protein: Int
    var carbs: Int
    var fat: Int
}

@MainActor
final class MealAnalyzer {
    static let shared = MealAnalyzer()
    private let supabase = LevlaSupabase.shared

    /// Pump a single UIImage to `analyze-meal`. Returns nil if there's no
    /// session or the function couldn't extract anything.
    func analyze(image: UIImage) async throws -> AnalyzedMeal? {
        if supabase.isOffline {
            // Offline mock — useful in simulator without a key.
            return AnalyzedMeal(
                name: "Mixed salad bowl",
                kcal: 420, protein: 28, carbs: 32, fat: 22,
                confidence: 0.55,
                ingredients: [
                    AnalyzedIngredient(name: "Chicken breast", kcal: 180, protein: 24, carbs: 0, fat: 6),
                    AnalyzedIngredient(name: "Leafy greens",   kcal: 30,  protein: 2,  carbs: 6, fat: 0),
                    AnalyzedIngredient(name: "Dressing",       kcal: 210, protein: 2,  carbs: 26, fat: 16),
                ]
            )
        }

        guard let client = supabase.client else { return nil }
        guard let session = try? await client.auth.session, !session.accessToken.isEmpty else {
            throw AIScanError.notSignedIn
        }
        guard let jpeg = jpegResized(image, maxEdge: 1024, quality: 0.75) else { return nil }
        let dataURI = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"

        let payload = AnalyzeRequest(image: dataURI)
        // Bypass auto-decode so we can parse defensively.
        let data = try await client.functions.invoke("analyze-meal",
                                                     options: .init(body: payload)) {
            (data: Data, response: HTTPURLResponse) -> Data in
            if 200..<300 ~= response.statusCode { return data }
            throw FunctionsError.httpError(code: response.statusCode, data: data)
        }
        return parse(from: data)
    }

    private func parse(from data: Data) -> AnalyzedMeal? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // Backend may wrap it as { meal: {...} } or return the meal at root.
        let mealDict = (root["meal"] as? [String: Any]) ?? root

        func str(_ d: [String: Any], _ keys: String...) -> String? {
            for k in keys {
                if let v = d[k] as? String { return v }
                if let n = d[k] as? Double { return String(n) }
                if let n = d[k] as? Int    { return String(n) }
            }
            return nil
        }
        func int(_ d: [String: Any], _ keys: String...) -> Int? {
            for k in keys {
                if let v = d[k] as? Int    { return v }
                if let v = d[k] as? Double { return Int(v) }
                if let s = d[k] as? String, let v = Int(s) { return v }
            }
            return nil
        }
        func double(_ d: [String: Any], _ keys: String...) -> Double? {
            for k in keys {
                if let v = d[k] as? Double { return v }
                if let v = d[k] as? Int    { return Double(v) }
                if let s = d[k] as? String, let v = Double(s) { return v }
            }
            return nil
        }

        let ingRaw = (mealDict["ingredients"] as? [[String: Any]]) ?? []
        let ingredients: [AnalyzedIngredient] = ingRaw.map { d in
            AnalyzedIngredient(
                name:    str(d, "name", "title") ?? "Ingredient",
                kcal:    int(d, "kcal", "calories") ?? 0,
                protein: int(d, "protein", "protein_g") ?? 0,
                carbs:   int(d, "carbs", "carbs_g") ?? 0,
                fat:     int(d, "fat", "fat_g") ?? 0
            )
        }

        return AnalyzedMeal(
            name:       str(mealDict, "name", "title", "label") ?? "Meal",
            kcal:       int(mealDict, "kcal", "calories") ?? 0,
            protein:    int(mealDict, "protein", "protein_g") ?? 0,
            carbs:      int(mealDict, "carbs", "carbs_g") ?? 0,
            fat:        int(mealDict, "fat", "fat_g") ?? 0,
            confidence: double(mealDict, "confidence", "score") ?? 0.7,
            ingredients: ingredients
        )
    }

    private struct AnalyzeRequest: Encodable { let image: String }
}

// Local copy of the same downscaler used by AIScanService, kept here to
// avoid coupling the two services. Identical math.
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

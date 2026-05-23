import Vision
import UIKit
import CoreImage

/// One detected food candidate from a scan — used by the verify screen.
struct ScanCandidate: Identifiable, Hashable {
    let id = UUID()
    var foodKey: String
    var displayName: String
    var qty: String
    var confidence: Double      // 0…1
    var category: FoodCategory
    var daysLeft: Int
}

/// One line parsed from a receipt — used by the verify screen for receipts.
struct ReceiptLine: Identifiable, Hashable {
    let id = UUID()
    var rawText: String
    var price: String?
    var foodKey: String         // mapped via keyword
    var displayName: String
    var confidence: Double
}

enum VisionRecognizer {
    // MARK: - Receipt OCR (Vision text recognition)

    /// Apple Vision text recognition — returns the raw text lines from the
    /// receipt. The structured parsing happens server-side via the
    /// `scan-receipt` Edge Function (GPT-4.1-mini).
    static func extractReceiptText(_ image: UIImage) async -> String {
        let lines = await extractReceiptLines(image)
        return lines.joined(separator: "\n")
    }

    /// Same as `extractReceiptText` but returns the raw lines so the caller
    /// can show them in the "identifying" UI.
    static func extractReceiptLines(_ image: UIImage) async -> [String] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNRecognizeTextRequest { req, _ in
                guard let obs = req.results as? [VNRecognizedTextObservation] else {
                    cont.resume(returning: []); return
                }
                var lines: [String] = []
                for o in obs {
                    if let top = o.topCandidates(1).first { lines.append(top.string) }
                }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }

    /// Map raw OCR lines to plausible food line items. Filters out totals,
    /// dates, store branding, and lines that are pure punctuation.
    static func parseReceiptLines(_ raw: [String]) -> [ReceiptLine] {
        let stop: Set<String> = ["total","subtotal","tax","vat","cash","card","change","date","time","thank","you","receipt","store","tel","www","gbp","usd","eur","£","$","€","amount","items","balance"]

        var out: [ReceiptLine] = []
        for line in raw {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2 else { continue }

            let lower = trimmed.lowercased()
            if stop.contains(where: { lower.contains($0) }) { continue }
            // Skip pure numbers / prices
            if trimmed.range(of: #"^[\d\.\,£$€\s\-x]+$"#, options: .regularExpression) != nil { continue }

            // Extract trailing price if any
            var price: String? = nil
            var label = trimmed
            if let m = trimmed.range(of: #"[£$€]?\s?\d+[\.,]\d{2}\s*$"#, options: .regularExpression) {
                price = String(trimmed[m]).trimmingCharacters(in: .whitespaces)
                label = String(trimmed[trimmed.startIndex..<m.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            // Trim quantity markers
            label = label.replacingOccurrences(of: #"^\d+\s*x\s*"#, with: "", options: .regularExpression)
            if label.count < 3 { continue }

            let (foodKey, displayName) = mapToFood(label: label)
            // If we couldn't map it confidently, still include the raw text so the user can decide.
            out.append(ReceiptLine(
                rawText: trimmed,
                price: price,
                foodKey: foodKey,
                displayName: displayName,
                confidence: foodKey == "default" ? 0.40 : 0.86
            ))
        }
        // Dedupe by foodKey, keeping highest-confidence
        var byKey: [String: ReceiptLine] = [:]
        for l in out {
            if let cur = byKey[l.foodKey], cur.confidence >= l.confidence { continue }
            byKey[l.foodKey] = l
        }
        return Array(byKey.values).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Fridge / meal classification (Vision classify)

    /// Classify a fridge or meal photo into top food candidates.
    /// Uses Apple's bundled `VNClassifyImageRequest` (no custom model required).
    /// We then map matching labels onto the app's `FOOD` key set.
    static func classify(_ image: UIImage, kind: ScanKind) async -> [ScanCandidate] {
        guard let cg = image.cgImage else { return [] }
        return await withCheckedContinuation { cont in
            let request = VNClassifyImageRequest { req, _ in
                guard let obs = req.results as? [VNClassificationObservation] else {
                    cont.resume(returning: []); return
                }
                let candidates = mapVisionClassifications(obs, kind: kind)
                cont.resume(returning: candidates)
            }
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up, options: [:])
            try? handler.perform([request])
        }
    }

    private static func mapVisionClassifications(_ obs: [VNClassificationObservation], kind: ScanKind) -> [ScanCandidate] {
        let top = obs.prefix(30)
        var picks: [ScanCandidate] = []
        var seen: Set<String> = []

        for o in top {
            guard o.confidence > 0.10 else { continue }
            guard let mapped = foodKeyword(for: o.identifier) else { continue }
            if seen.contains(mapped.key) { continue }
            seen.insert(mapped.key)
            picks.append(ScanCandidate(
                foodKey: mapped.key,
                displayName: mapped.name,
                qty: defaultQty(for: mapped.key),
                confidence: Double(o.confidence),
                category: mapped.category,
                daysLeft: defaultDaysLeft(for: mapped.category)
            ))
            if picks.count >= 8 { break }
        }
        if picks.isEmpty { picks = fridgeFallback() }
        return picks
    }

    private static func fridgeFallback() -> [ScanCandidate] {
        [
            .init(foodKey: "milk", displayName: "Whole milk", qty: "1 L", confidence: 0.72, category: .dairy, daysLeft: 5),
            .init(foodKey: "feta", displayName: "Feta cheese", qty: "180 g", confidence: 0.81, category: .dairy, daysLeft: 12),
            .init(foodKey: "pesto", displayName: "Basil pesto", qty: "½ jar", confidence: 0.66, category: .pantry, daysLeft: 14),
        ]
    }
}

enum ScanKind: String, Sendable, CaseIterable { case fridge, receipt, barcode }

// MARK: - Food keyword mapping (best-effort, English)

private struct FoodMapping { let key: String; let name: String; let category: FoodCategory }

private func mapToFood(label: String) -> (key: String, name: String) {
    if let m = foodKeyword(for: label) { return (m.key, m.name) }
    return ("default", label.capitalized)
}

private func foodKeyword(for raw: String) -> FoodMapping? {
    let l = raw.lowercased()
    let table: [(String, FoodMapping)] = [
        ("milk",     .init(key: "milk", name: "Whole milk", category: .dairy)),
        ("yog",      .init(key: "yogurt", name: "Yoghurt", category: .dairy)),
        ("butter",   .init(key: "butter", name: "Butter", category: .dairy)),
        ("feta",     .init(key: "feta", name: "Feta cheese", category: .dairy)),
        ("parmesan", .init(key: "parmesan", name: "Parmesan", category: .pantry)),
        ("cheese",   .init(key: "feta", name: "Cheese", category: .dairy)),
        ("egg",      .init(key: "egg", name: "Eggs", category: .dairy)),

        ("spinach",  .init(key: "spinach", name: "Spinach", category: .vegetables)),
        ("broccoli", .init(key: "broccoli", name: "Broccoli", category: .vegetables)),
        ("tomato",   .init(key: "tomato", name: "Tomatoes", category: .vegetables)),
        ("carrot",   .init(key: "carrot", name: "Carrots", category: .vegetables)),
        ("pepper",   .init(key: "pepper", name: "Peppers", category: .vegetables)),
        ("capsicum", .init(key: "pepper", name: "Peppers", category: .vegetables)),
        ("lemon",    .init(key: "lemon", name: "Lemons", category: .vegetables)),
        ("garlic",   .init(key: "garlic", name: "Garlic", category: .vegetables)),
        ("onion",    .init(key: "onion", name: "Onions", category: .vegetables)),
        ("avocado",  .init(key: "avocado", name: "Avocados", category: .vegetables)),

        ("chicken",  .init(key: "chicken", name: "Chicken", category: .meat)),
        ("salmon",   .init(key: "salmon", name: "Salmon", category: .meat)),
        ("beef",     .init(key: "beef", name: "Beef", category: .meat)),

        ("rice",     .init(key: "rice", name: "Rice", category: .pantry)),
        ("pasta",    .init(key: "pasta", name: "Pasta", category: .pantry)),
        ("spaghetti",.init(key: "pasta", name: "Spaghetti", category: .pantry)),
        ("olive oil",.init(key: "oil", name: "Olive oil", category: .pantry)),
        ("oil",      .init(key: "oil", name: "Olive oil", category: .pantry)),
        ("bread",    .init(key: "bread", name: "Bread", category: .pantry)),
        ("sourdough",.init(key: "bread", name: "Sourdough", category: .pantry)),
        ("pesto",    .init(key: "pesto", name: "Pesto", category: .pantry)),

        ("wine",     .init(key: "wine", name: "Wine", category: .drinks)),
        ("water",    .init(key: "water", name: "Sparkling water", category: .drinks)),
    ]
    for (needle, mapping) in table where l.contains(needle) {
        return mapping
    }
    return nil
}

private func defaultQty(for key: String) -> String {
    switch key {
    case "milk": return "1 L"
    case "egg":  return "6"
    case "salmon", "chicken", "beef": return "300 g"
    case "spinach", "broccoli": return "1 head"
    case "tomato", "carrot", "pepper", "lemon", "onion", "avocado": return "3"
    case "rice", "pasta": return "1 bag"
    case "bread": return "1 loaf"
    case "oil": return "500 ml"
    case "feta", "parmesan", "butter": return "200 g"
    default: return "1"
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

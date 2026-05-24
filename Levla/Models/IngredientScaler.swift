import Foundation

/// Scales the leading numeric quantity in an ingredient amount string by a
/// given factor. Handles integers, decimals, common unicode fractions
/// (½ ⅓ ⅔ ¼ ¾ ⅛ ⅜ ⅝ ⅞), simple ranges ("1-2", "1 to 2"), and "1 ½" mixes.
///
/// Examples (factor = 2):
///   "150 g chicken breast"   → "300 g chicken breast"
///   "½ tsp salt"             → "1 tsp salt"
///   "1-2 cloves garlic"      → "2-4 cloves garlic"
///   "1 ½ cups rice"          → "3 cups rice"
///   "1 medium yellow onion"  → "2 medium yellow onion"
///   "to taste"               → "to taste"           (untouched)
///   "a pinch of salt"        → "a pinch of salt"    (untouched)
///
/// We deliberately don't try to convert units (e.g. "2 tsp" stays "2 tsp"
/// even when scaling by 6 — never becomes "1 cup"). Just doubles/halves the
/// number the user can read at a glance.
enum IngredientScaler {

    /// Map of leading unicode fractions → decimal value.
    private static let fractionMap: [Character: Double] = [
        "½": 0.5, "⅓": 1.0/3, "⅔": 2.0/3,
        "¼": 0.25, "¾": 0.75,
        "⅕": 0.2, "⅖": 0.4, "⅗": 0.6, "⅘": 0.8,
        "⅙": 1.0/6, "⅚": 5.0/6,
        "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
    ]

    static func scale(_ amount: String, factor: Double) -> String {
        guard factor > 0, factor != 1.0 else { return amount }
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return amount }

        // Range form: "1-2", "1 - 2", "1 to 2"
        if let scaled = scaleRange(trimmed, factor: factor) { return scaled }

        // Mixed number "1 ½"
        if let scaled = scaleMixed(trimmed, factor: factor) { return scaled }

        // Leading unicode fraction "½ tsp salt"
        if let scaled = scaleLeadingFraction(trimmed, factor: factor) { return scaled }

        // Leading plain number "150 g..." or "1.5 cups..."
        if let scaled = scaleLeadingNumber(trimmed, factor: factor) { return scaled }

        // Nothing parseable — return as-is. ("a pinch", "to taste")
        return amount
    }

    // MARK: - Internal helpers

    private static func scaleRange(_ s: String, factor: Double) -> String? {
        // Matches "1-2 cups", "1 - 2 cups", "1 to 2 cups". Greedy so it
        // captures decimals too.
        let pattern = #"^(\d+(?:\.\d+)?)\s*(?:-|\s+to\s+)\s*(\d+(?:\.\d+)?)\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges >= 4,
              let a = Range(m.range(at: 1), in: s),
              let b = Range(m.range(at: 2), in: s),
              let rest = Range(m.range(at: 3), in: s),
              let na = Double(s[a]), let nb = Double(s[b])
        else { return nil }
        return "\(format(na * factor))-\(format(nb * factor)) \(s[rest])".trimmingCharacters(in: .whitespaces)
    }

    private static func scaleMixed(_ s: String, factor: Double) -> String? {
        // "1 ½ cups rice" — integer space fraction. Combine then scale.
        let pattern = #"^(\d+)\s+([½⅓⅔¼¾⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞])\s+(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges >= 4,
              let intR = Range(m.range(at: 1), in: s),
              let fracR = Range(m.range(at: 2), in: s),
              let restR = Range(m.range(at: 3), in: s),
              let i = Double(s[intR]),
              let f = s[fracR].first.flatMap({ fractionMap[$0] })
        else { return nil }
        let total = (i + f) * factor
        return "\(format(total)) \(s[restR])".trimmingCharacters(in: .whitespaces)
    }

    private static func scaleLeadingFraction(_ s: String, factor: Double) -> String? {
        guard let first = s.first, let value = fractionMap[first] else { return nil }
        // Skip the fraction char + leading whitespace
        let rest = s.dropFirst().drop(while: { $0.isWhitespace })
        let scaled = value * factor
        return "\(format(scaled)) \(rest)".trimmingCharacters(in: .whitespaces)
    }

    private static func scaleLeadingNumber(_ s: String, factor: Double) -> String? {
        let pattern = #"^(\d+(?:\.\d+)?)\s*(.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges >= 3,
              let numR = Range(m.range(at: 1), in: s),
              let restR = Range(m.range(at: 2), in: s),
              let n = Double(s[numR])
        else { return nil }
        return "\(format(n * factor)) \(s[restR])".trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Number formatting

    /// Format a decimal back to a human-friendly amount. Prefers integers,
    /// then common fractions, then one decimal place.
    private static func format(_ x: Double) -> String {
        let rounded = (x * 1000).rounded() / 1000
        if abs(rounded - rounded.rounded()) < 0.01 {
            return String(Int(rounded.rounded()))
        }
        // Try to match common fractions for nicer rendering.
        let fractionRepresentations: [(Double, String)] = [
            (0.125, "⅛"), (0.25, "¼"), (1.0/3, "⅓"),
            (0.375, "⅜"), (0.5, "½"), (0.625, "⅝"),
            (2.0/3, "⅔"), (0.75, "¾"), (0.875, "⅞"),
        ]
        let intPart = floor(rounded)
        let frac = rounded - intPart
        for (val, glyph) in fractionRepresentations {
            if abs(frac - val) < 0.03 {
                if intPart == 0 { return glyph }
                return "\(Int(intPart)) \(glyph)"
            }
        }
        return String(format: "%.1f", rounded)
    }
}

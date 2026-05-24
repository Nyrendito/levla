import Foundation

/// Cal-AI-style 0-10 daily Health Score. Combines how well the user is
/// tracking macros + micros against their personalized goals, plus simple
/// penalties for going over sugar/sodium ceilings.
///
/// Returns nil until at least one meal is logged for the day.
struct HealthScore {
    let score: Int               // 0…10
    let commentary: String       // short AI-style summary, computed locally

    /// Compose a score from today's eaten totals + the personalized targets.
    static func compute(
        kcal: Int, kcalGoal: Int?,
        protein: Int, proteinGoal: Int?,
        carbs: Int, carbsGoal: Int?,
        fat: Int, fatGoal: Int?,
        fiber: Int, fiberGoal: Int?,
        sugar: Int, sugarGoal: Int?,
        sodium: Int, sodiumGoal: Int?,
        hasLogs: Bool
    ) -> HealthScore? {
        guard hasLogs else { return nil }

        // Each axis worth 1 point. 7 axes → normalized to 10.
        var points: Double = 0
        var lows: [String] = []
        var highs: [String] = []
        var wins: [String] = []

        // Kcal: 1 point if within ±15% of goal. Otherwise partial credit.
        if let goal = kcalGoal, goal > 0 {
            let ratio = Double(kcal) / Double(goal)
            if ratio >= 0.85 && ratio <= 1.15 {
                points += 1; wins.append("calories on target")
            } else if ratio < 0.85 {
                points += 0.4; lows.append("calories")
            } else {
                points += 0.4; highs.append("calories")
            }
        }

        // Protein: 1 point if at or above goal, 0.6 if 80%+, otherwise low.
        if let goal = proteinGoal, goal > 0 {
            let ratio = Double(protein) / Double(goal)
            if ratio >= 1.0 { points += 1; wins.append("protein hit") }
            else if ratio >= 0.8 { points += 0.7 }
            else { points += 0.3; lows.append("protein") }
        }

        // Carbs + fat: 1 point if within ±20%
        if let goal = carbsGoal, goal > 0 {
            let ratio = Double(carbs) / Double(goal)
            if ratio >= 0.8 && ratio <= 1.2 { points += 1 }
            else if ratio < 0.8 { points += 0.5; lows.append("carbs") }
            else { points += 0.4; highs.append("carbs") }
        }
        if let goal = fatGoal, goal > 0 {
            let ratio = Double(fat) / Double(goal)
            if ratio >= 0.8 && ratio <= 1.2 { points += 1 }
            else if ratio < 0.8 { points += 0.5; lows.append("fats") }
            else { points += 0.4; highs.append("fats") }
        }

        // Fiber: 1 point if at or above goal, scaled.
        if let goal = fiberGoal, goal > 0 {
            let ratio = Double(fiber) / Double(goal)
            if ratio >= 1.0 { points += 1; wins.append("fiber hit") }
            else if ratio >= 0.7 { points += 0.7 }
            else { points += 0.3; lows.append("fiber") }
        }

        // Sugar: 1 point if at or below goal (lower is better). Full penalty
        // above 1.5× goal.
        if let goal = sugarGoal, goal > 0 {
            let ratio = Double(sugar) / Double(goal)
            if ratio <= 1.0 { points += 1; wins.append("low sugar") }
            else if ratio <= 1.5 { points += 0.5; highs.append("sugar") }
            else { points += 0; highs.append("sugar") }
        }

        // Sodium: same pattern as sugar.
        if let goal = sodiumGoal, goal > 0 {
            let ratio = Double(sodium) / Double(goal)
            if ratio <= 1.0 { points += 1; wins.append("low sodium") }
            else if ratio <= 1.5 { points += 0.5; highs.append("sodium") }
            else { points += 0; highs.append("sodium") }
        }

        // Normalize: 7 axes max. Round to nearest int 0–10.
        let normalized = (points / 7.0) * 10.0
        let intScore = max(0, min(10, Int(normalized.rounded())))

        // Commentary: assemble in Cal-AI's voice.
        let commentary = buildCommentary(score: intScore, wins: wins, lows: lows, highs: highs)
        return HealthScore(score: intScore, commentary: commentary)
    }

    private static func buildCommentary(
        score: Int, wins: [String], lows: [String], highs: [String]
    ) -> String {
        if score >= 8 {
            let win = wins.first ?? "macros"
            return "Strong day — \(win) and most of your targets look balanced. Keep this rhythm going."
        }
        if score >= 5 {
            if !lows.isEmpty && !highs.isEmpty {
                return "Your \(joined(lows)) are below goal and your \(joined(highs)) are running high — adjust your next meal to balance."
            }
            if !lows.isEmpty {
                return "Your \(joined(lows)) are below goal; focus on lifting those at your next meal."
            }
            if !highs.isEmpty {
                return "Your \(joined(highs)) are running over today — go lighter on those at your next meal."
            }
            return "You're tracking — keep logging meals to sharpen the score."
        }
        if !highs.isEmpty {
            return "Your \(joined(highs)) are well over goal. Try a lighter, fibre-heavy next meal."
        }
        return "Eat something more balanced next — protein, fibre, and water to ground the day."
    }

    private static func joined(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        case 2: return "\(items[0]) and \(items[1])"
        default:
            let last = items.last!
            let front = items.dropLast().joined(separator: ", ")
            return "\(front), and \(last)"
        }
    }
}

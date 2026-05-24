import SwiftUI
import Charts

/// Cal-AI-inspired Progress tab — adapted for Levla's premise (cooking from
/// your fridge, not just calorie counting).
///
/// Top: Weight card + Streak card (side-by-side).
/// Middle: Time-range tabs → Goal Progress weight chart.
/// Then: Week selector → Total Calories stacked bar chart with daily kcal
///       goal overlay.
/// Then: Macro hit-rate card (kcal in range / protein hit, days out of 7).
/// Then: From-your-fridge card (items scanned vs meals cooked this week).
struct ProgressView: View {
    @Environment(AppState.self) private var app

    @State private var weighInOpen = false
    @State private var weekOffset: Int = 0          // 0 = this week, 1 = last, etc.
    @State private var rangeWindow: WeightWindow = .ninetyDays

    enum WeightWindow: String, CaseIterable {
        case ninetyDays = "90 Days"
        case sixMonths  = "6 Months"
        case oneYear    = "1 Year"
        case allTime    = "All time"

        var days: Int {
            switch self {
            case .ninetyDays: return 90
            case .sixMonths:  return 182
            case .oneYear:    return 365
            case .allTime:    return 3_650
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 60)

                HStack(spacing: 12) {
                    weightCard
                    streakCard
                }
                .padding(.horizontal, L.S.pad)

                rangeTabs
                    .padding(.horizontal, L.S.pad)

                goalProgressCard
                    .padding(.horizontal, L.S.pad)

                weekTabs
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 6)

                caloriesCard
                    .padding(.horizontal, L.S.pad)

                macroHitCard
                    .padding(.horizontal, L.S.pad)

                fromYourFridgeCard
                    .padding(.horizontal, L.S.pad)

                Color.clear.frame(height: 140)
            }
        }
        .background(L.paper.ignoresSafeArea())
        .task {
            if let uid = app.auth.currentUserId {
                async let h: Void = app.cooked.reloadHistory(userId: uid)
                async let w: Void = app.weightLog.reload(userId: uid)
                _ = await (h, w)
            }
        }
        .sheet(isPresented: $weighInOpen) {
            WeighInSheet()
                .presentationDetents([.height(420)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Progress")
                .font(.manrope(34, .heavy))
                .kerning(-1.0)
                .foregroundStyle(L.ink)
            Spacer()
        }
    }

    // MARK: - Top row cards

    private var weightCard: some View {
        let kg = app.weightLog.latestKg ?? app.currentProfile?.weightKg
        let goal = app.currentProfile?.weightKg.map { _ in goalWeight }
        let nextLabel = nextWeighInLabel()
        return Button(action: { weighInOpen = true }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("My Weight")
                    .font(.manrope(12, .heavy))
                    .tracking(0.4)
                    .foregroundStyle(L.muted)

                if let kg {
                    Text("\(kg, specifier: "%.0f") kg")
                        .font(.manrope(30, .heavy))
                        .kerning(-0.6)
                        .foregroundStyle(L.ink)
                } else {
                    Text("— kg")
                        .font(.manrope(30, .heavy))
                        .foregroundStyle(L.ink.opacity(0.4))
                }

                weightProgressBar
                    .frame(height: 5)
                    .padding(.top, 2)

                if let goal {
                    Text("Goal \(goal, specifier: "%.0f") kg")
                        .font(.manrope(11.5, .semibold))
                        .foregroundStyle(L.muted)
                } else {
                    Text("Set a goal in Profile")
                        .font(.manrope(11.5, .semibold))
                        .foregroundStyle(L.muted)
                }

                Spacer(minLength: 0)

                Text(nextLabel)
                    .font(.manrope(11, .heavy))
                    .tracking(0.3)
                    .foregroundStyle(app.weightLog.needsWeighIn ? L.pop : L.ink.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )
            .modifier(_PSoft())
        }
        .buttonStyle(.plain)
    }

    private var weightProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(L.ink.opacity(0.08))
                Capsule()
                    .fill(L.ink)
                    .frame(width: proxy.size.width * weightProgressRatio)
            }
        }
    }

    /// Fraction of the way from where you started to your goal.
    private var weightProgressRatio: CGFloat {
        guard let kg = app.weightLog.latestKg ?? app.currentProfile?.weightKg,
              let startKg = app.weightLog.logs.min(by: { $0.loggedAt < $1.loggedAt })?.weightKg
                ?? app.currentProfile?.weightKg
        else { return 0 }
        let goal = goalWeight
        guard startKg != goal else { return 1 }
        let ratio = (kg - startKg) / (goal - startKg)
        return CGFloat(max(0, min(1, ratio)))
    }

    /// "Set a goal" surfaced from Profile if available, otherwise a soft
    /// default derived from current weight + goal direction.
    private var goalWeight: Double {
        if let kg = app.currentProfile?.weightKg {
            switch app.currentProfile?.goal {
            case .loseFat?:    return kg - 5
            case .gainMuscle?: return kg + 5
            default:           return kg
            }
        }
        return 70
    }

    private func nextWeighInLabel() -> String {
        if let days = app.weightLog.daysSinceLatest {
            if days >= 7 { return "Weigh in now" }
            return "Next weigh-in: \(7 - days)d"
        }
        return "Log your first weigh-in"
    }

    private var streakCard: some View {
        let dots = ProgressStats.cookedFromFridgeWeekDots(entries: app.cooked.historyEntries)
        let streak = ProgressStats.cookedFromFridgeStreak(entries: app.cooked.historyEntries)
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("🔥").font(.system(size: 28))
                Text("\(streak)")
                    .font(.manrope(30, .heavy))
                    .kerning(-0.6)
                    .foregroundStyle(L.pop)
            }
            .padding(.top, 6)

            Text(streak == 1 ? "Day Streak" : "Day Streak")
                .font(.manrope(13, .heavy))
                .tracking(0.2)
                .foregroundStyle(L.pop)

            HStack(spacing: 6) {
                ForEach(Array(dots.enumerated()), id: \.offset) { (i, hit) in
                    let label = weekdayShort(daysAgo: 6 - i)
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(hit ? L.pop : L.ink.opacity(0.08))
                            if hit {
                                LSymbol(key: "check", size: 9, weight: .heavy).foregroundStyle(.white)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(label)
                            .font(.manrope(9, .heavy))
                            .foregroundStyle(L.muted)
                    }
                }
            }
            .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    private func weekdayShort(daysAgo: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEEE"
        return fmt.string(from: d).uppercased()
    }

    // MARK: - Time-range tabs (for the weight chart)

    private var rangeTabs: some View {
        HStack(spacing: 0) {
            ForEach(WeightWindow.allCases, id: \.self) { window in
                let active = window == rangeWindow
                Button { rangeWindow = window } label: {
                    Text(window.rawValue)
                        .font(.manrope(12.5, .heavy))
                        .foregroundStyle(active ? L.ink : L.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(active ? Color.white : Color.clear)
                                .modifier(_RangeTabShadow(active: active))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(L.ink.opacity(0.06), in: Capsule())
    }

    // MARK: - Goal Progress chart

    private var goalProgressCard: some View {
        let points = ProgressStats.weightTrend(logs: app.weightLog.logs, windowDays: rangeWindow.days)
        let pct = ProgressStats.goalProgress(
            logs: app.weightLog.logs,
            startWeightKg: nil,
            goalWeightKg: goalWeight
        )
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Goal Progress")
                    .font(.manrope(18, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                Spacer()
                if let pct {
                    HStack(spacing: 4) {
                        LSymbol(key: "check", size: 10, weight: .heavy).foregroundStyle(L.ink)
                        Text("\(pct)%")
                            .font(.manrope(13, .heavy))
                            .foregroundStyle(L.ink)
                        Text("of goal")
                            .font(.manrope(13, .semibold))
                            .foregroundStyle(L.muted)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(L.ink.opacity(0.06), in: Capsule())
                }
            }

            if points.count >= 2 {
                Chart(points, id: \.date) { p in
                    LineMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", p.weightKg)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .foregroundStyle(L.ink)
                    AreaMark(
                        x: .value("Date", p.date),
                        y: .value("Weight", p.weightKg)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(
                        colors: [L.ink.opacity(0.10), L.ink.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .automatic(desiredCount: 3)) {
                        AxisValueLabel().foregroundStyle(L.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) {
                        AxisGridLine().foregroundStyle(L.hairline)
                        AxisValueLabel().foregroundStyle(L.muted)
                    }
                }
            } else {
                emptyChart(text: "Log your weight to see your progress.")
            }

            // Motivational caption
            Text(goalCaption)
                .font(.manrope(12.5, .heavy))
                .foregroundStyle(L.brand)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(L.brandBg, in: Capsule())
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    private var goalCaption: String {
        let logs = app.weightLog.logs
        guard logs.count >= 2 else { return "Getting started is the hardest part. You're ready for this!" }
        // Compare latest to ~7 days ago.
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = logs.filter { $0.loggedAt >= weekAgo }
        guard let latest = recent.max(by: { $0.loggedAt < $1.loggedAt })?.weightKg,
              let earlier = recent.min(by: { $0.loggedAt < $1.loggedAt })?.weightKg else {
            return "Keep logging weekly — Levla learns from every weigh-in."
        }
        let diff = latest - earlier
        switch app.currentProfile?.goal {
        case .loseFat?:
            if diff < -0.2 { return "Down \(abs(diff).rounded10) kg this week. Keep going!" }
            if diff > 0.5  { return "Slight uptick this week — stay consistent." }
            return "Steady this week. Small wins stack up."
        case .gainMuscle?:
            if diff > 0.2  { return "Up \(diff.rounded10) kg this week. Great work!" }
            return "Solid baseline. Keep the protein up."
        default:
            return "Holding steady. That's the goal."
        }
    }

    // MARK: - Week tabs

    private var weekTabs: some View {
        let labels = ["This week", "Last week", "2 wks. ago", "3 wks. ago"]
        return HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { (i, label) in
                let active = i == weekOffset
                Button { weekOffset = i } label: {
                    Text(label)
                        .font(.manrope(12.5, .heavy))
                        .foregroundStyle(active ? L.ink : L.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(active ? Color.white : Color.clear)
                                .modifier(_RangeTabShadow(active: active))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(L.ink.opacity(0.06), in: Capsule())
    }

    // MARK: - Total Calories card

    private var caloriesCard: some View {
        let days = ProgressStats.weeklyDailyTotals(entries: app.cooked.historyEntries, weekOffset: weekOffset)
        let total = days.reduce(0) { $0 + $1.kcal }
        let kcalGoal = app.currentProfile?.dailyKcalGoal
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Total Calories")
                    .font(.manrope(18, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(total.formatted())")
                    .font(.manrope(34, .heavy))
                    .kerning(-0.8)
                    .foregroundStyle(L.ink)
                Text("cals")
                    .font(.manrope(13, .heavy))
                    .foregroundStyle(L.muted)
            }

            if days.contains(where: { $0.kcal > 0 }) {
                Chart {
                    ForEach(days, id: \.date) { d in
                        BarMark(
                            x: .value("Day", d.date, unit: .day),
                            y: .value("Protein", d.protein * 4)
                        )
                        .foregroundStyle(L.macroProtein)
                        BarMark(
                            x: .value("Day", d.date, unit: .day),
                            y: .value("Carbs", d.carbs * 4)
                        )
                        .foregroundStyle(L.macroCarbs)
                        BarMark(
                            x: .value("Day", d.date, unit: .day),
                            y: .value("Fat", d.fat * 9)
                        )
                        .foregroundStyle(L.macroFat)
                    }
                    if let kcalGoal {
                        RuleMark(y: .value("Goal", kcalGoal))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(L.ink.opacity(0.55))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Goal \(kcalGoal)")
                                    .font(.manrope(9.5, .heavy))
                                    .tracking(0.2)
                                    .foregroundStyle(L.muted)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.white, in: Capsule())
                            }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                            .foregroundStyle(L.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) {
                        AxisGridLine().foregroundStyle(L.hairline)
                        AxisValueLabel().foregroundStyle(L.muted)
                    }
                }
            } else {
                emptyChart(text: "Log a meal to see your week.")
            }

            HStack(spacing: 18) {
                legendDot(color: L.macroProtein, label: "Protein")
                legendDot(color: L.macroCarbs,   label: "Carbs")
                legendDot(color: L.macroFat,     label: "Fat")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.manrope(11.5, .heavy))
                .foregroundStyle(L.muted)
        }
    }

    // MARK: - Macro hit-rate

    private var macroHitCard: some View {
        let rate = ProgressStats.macroHitRate(
            entries: app.cooked.historyEntries,
            weekOffset: weekOffset,
            kcalGoal: app.currentProfile?.dailyKcalGoal,
            proteinGoal: app.currentProfile?.dailyProteinGoal
        )
        return VStack(alignment: .leading, spacing: 14) {
            Text("Goal hit-rate")
                .font(.manrope(18, .heavy))
                .kerning(-0.3)
                .foregroundStyle(L.ink)

            HStack(spacing: 12) {
                hitRatePill(
                    label: "Kcal in range",
                    value: "\(rate.kcalInRange)/\(rate.total)",
                    color: L.macroFat
                )
                hitRatePill(
                    label: "Protein hit",
                    value: "\(rate.proteinHit)/\(rate.total)",
                    color: L.macroProtein
                )
            }

            if app.currentProfile?.dailyKcalGoal == nil {
                Text("Finish onboarding to unlock goal tracking.")
                    .font(.manrope(11.5, .semibold))
                    .foregroundStyle(L.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    private func hitRatePill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label.uppercased())
                    .font(.manrope(10, .heavy))
                    .tracking(1.0)
                    .foregroundStyle(L.muted)
            }
            Text(value)
                .font(.manrope(22, .heavy))
                .kerning(-0.4)
                .foregroundStyle(L.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(L.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
    }

    // MARK: - From your fridge

    private var fromYourFridgeCard: some View {
        let usage = ProgressStats.fridgeUsage(
            fridgeItems: app.fridge.items,
            cookedEntries: app.cooked.historyEntries
        )
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(L.brandBg)
                    LSymbol(key: "fridge", size: 16, weight: .semibold).foregroundStyle(L.brand)
                }
                .frame(width: 36, height: 36)
                Text("From your fridge")
                    .font(.manrope(18, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                Spacer()
            }

            HStack(spacing: 14) {
                fridgeStatBlock(value: "\(usage.itemsScanned)", label: "items scanned")
                fridgeStatBlock(value: "\(usage.mealsCooked)",  label: "meals from fridge")
            }

            if usage.itemsScanned == 0 && usage.mealsCooked == 0 {
                Text("Scan your fridge to start the loop.")
                    .font(.manrope(12, .semibold))
                    .foregroundStyle(L.muted)
            } else {
                Text(fridgeUsageCaption(usage))
                    .font(.manrope(12.5, .semibold))
                    .foregroundStyle(L.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    private func fridgeStatBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.manrope(28, .heavy))
                .kerning(-0.6)
                .foregroundStyle(L.ink)
            Text(label.uppercased())
                .font(.manrope(10, .heavy))
                .tracking(0.8)
                .foregroundStyle(L.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(L.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
    }

    private func fridgeUsageCaption(_ usage: ProgressStats.FridgeUsage) -> String {
        if usage.mealsCooked == 0 {
            return "You stocked the fridge but haven't cooked anything from it yet. Open Cook to find a quick win."
        }
        if usage.itemsScanned == 0 {
            return "You cooked \(usage.mealsCooked) meal\(usage.mealsCooked == 1 ? "" : "s") from your fridge this week. Scan it again to keep recipes fresh."
        }
        return "You scanned \(usage.itemsScanned) item\(usage.itemsScanned == 1 ? "" : "s") and cooked \(usage.mealsCooked) meal\(usage.mealsCooked == 1 ? "" : "s") from your fridge."
    }

    // MARK: - Empty chart placeholder

    private func emptyChart(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(L.ink.opacity(0.03))
            Text(text)
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(height: 180)
    }
}

// MARK: - Shadows + modifiers

private struct _PSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

private struct _RangeTabShadow: ViewModifier {
    let active: Bool
    func body(content: Content) -> some View {
        if active {
            content.shadow(color: L.ink.opacity(0.06), radius: 4, x: 0, y: 1)
        } else {
            content
        }
    }
}

// MARK: - Helpers

private extension Double {
    /// 0.34 → "0.3"
    var rounded10: String {
        String(format: "%.1f", (self * 10).rounded() / 10)
    }
}

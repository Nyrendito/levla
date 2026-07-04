import SwiftUI

/// Multi-step onboarding shown the first time a freshly-signed-up user
/// reaches the app. Collects the fields that personalize their daily
/// kcal/macro targets + recipe suggestions:
///
/// 1. Sex
/// 2. Birth year (slider, age computed)
/// 3. Height (cm)
/// 4. Weight (kg)
/// 5. Activity level
/// 6. Goal
///
/// On completion we upsert `profiles` and mark `onboarded = true`.
struct OnboardingView: View {
    @Environment(AppState.self) private var app

    @State private var step: Int = 0
    @State private var sex: UserSex = .female
    @State private var birthYear: Int = Calendar.current.component(.year, from: Date()) - 28
    @State private var heightCm: Int = 170
    @State private var weightKg: Double = 70
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: UserGoal = .maintain
    @State private var saving: Bool = false
    /// Drives the "Building your personalised plan…" full-screen overlay.
    @State private var generatingPlan: Bool = false

    private let totalSteps = 6

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 12)

                Group {
                    switch step {
                    case 0: sexStep
                    case 1: ageStep
                    case 2: heightStep
                    case 3: weightStep
                    case 4: activityStep
                    case 5: goalStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
                    .padding(.horizontal, L.S.pad)
                    .padding(.bottom, 24)
            }

            // Full-screen "Building your personalised plan…" overlay shown
            // while generate-meal-plan runs at the very end of onboarding.
            if generatingPlan {
                PlanGenerationOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: generatingPlan)
    }

    // MARK: - Top progress

    private var progressBar: some View {
        VStack(spacing: 12) {
            HStack {
                if step > 0 {
                    Button { withAnimation { step -= 1 } } label: {
                        LSymbol(key: "chevron", size: 18, weight: .bold)
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(L.ink)
                            .frame(width: 38, height: 38)
                            .background(Color.white, in: Circle())
                            .modifier(_OnbShadow())
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 38, height: 38)
                }
                Spacer()
                Text("\(step + 1) of \(totalSteps)")
                    .font(.manrope(11.5, .heavy))
                    .tracking(1.2)
                    .foregroundStyle(L.muted)
                Spacer()
                Spacer().frame(width: 38, height: 38)
            }

            // Slim progress track
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(L.ink.opacity(0.08))
                    Capsule()
                        .fill(L.brand)
                        .frame(width: proxy.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
                        .animation(.easeInOut(duration: 0.25), value: step)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Steps

    private var sexStep: some View {
        OnbStep(
            title: "What's your sex?",
            sub: "We use this to estimate your daily energy needs."
        ) {
            VStack(spacing: 10) {
                ForEach(UserSex.allCases, id: \.self) { option in
                    OnbCard(
                        label: option.displayName,
                        selected: sex == option
                    ) { sex = option }
                }
            }
        }
    }

    private var ageStep: some View {
        let currentYear = Calendar.current.component(.year, from: Date())
        let computedAge = currentYear - birthYear
        return OnbStep(
            title: "How old are you?",
            sub: "Age changes how fast your body burns calories at rest."
        ) {
            VStack(spacing: 18) {
                Text("\(computedAge)")
                    .font(.manrope(72, .heavy))
                    .foregroundStyle(L.ink)
                Text("years")
                    .font(.manrope(13, .heavy))
                    .tracking(1.4)
                    .foregroundStyle(L.muted)

                Stepper(
                    value: Binding(
                        get: { computedAge },
                        set: { birthYear = currentYear - $0 }
                    ),
                    in: 13...100
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .padding(.top, 4)
            }
        }
    }

    private var heightStep: some View {
        OnbStep(
            title: "How tall are you?",
            sub: "In centimeters."
        ) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(heightCm)")
                        .font(.manrope(72, .heavy))
                        .foregroundStyle(L.ink)
                    Text("cm")
                        .font(.manrope(20, .heavy))
                        .foregroundStyle(L.muted)
                }
                Stepper(value: $heightCm, in: 120...230) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
    }

    private var weightStep: some View {
        OnbStep(
            title: "What's your weight?",
            sub: "We'll personalize portions and protein from this."
        ) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", weightKg))
                        .font(.manrope(72, .heavy))
                        .foregroundStyle(L.ink)
                    Text("kg")
                        .font(.manrope(20, .heavy))
                        .foregroundStyle(L.muted)
                }
                Stepper(
                    value: Binding(
                        get: { Int(weightKg * 10) },
                        set: { weightKg = Double($0) / 10 }
                    ),
                    in: 300...3000
                ) {
                    EmptyView()
                }
                .labelsHidden()
            }
        }
    }

    private var activityStep: some View {
        OnbStep(
            title: "How active are you?",
            sub: "Outside of cooking — work, walking, the gym."
        ) {
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases, id: \.self) { option in
                    OnbCard(
                        label: option.displayName,
                        sub: option.sublabel,
                        selected: activity == option
                    ) { activity = option }
                }
            }
        }
    }

    private var goalStep: some View {
        OnbStep(
            title: "What's your goal?",
            sub: "We'll bias recipes toward it. Change any time from your profile."
        ) {
            VStack(spacing: 10) {
                ForEach(UserGoal.allCases, id: \.self) { option in
                    OnbCard(
                        label: option.displayName,
                        emoji: option.emoji,
                        selected: goal == option
                    ) { goal = option }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        BigCTA(
            title: step == totalSteps - 1 ? (saving ? "Saving…" : "Finish") : "Continue",
            icon: step == totalSteps - 1 ? nil : "chevron",
            kind: .ink
        ) {
            if step < totalSteps - 1 {
                withAnimation { step += 1 }
            } else {
                Task { await finish() }
            }
        }
    }

    private func finish() async {
        guard let uid = app.auth.currentUserId, !saving else { return }
        saving = true
        defer { saving = false }

        // Use whatever profile we already have as the starting point — keeps
        // display_name, streak_days, etc.
        let base = app.currentProfile ?? Profile(id: uid)
        var updated = base
        updated.sex = sex
        updated.birthYear = birthYear
        updated.heightCm = heightCm
        updated.weightKg = (weightKg * 10).rounded() / 10
        updated.activityLevel = activity
        updated.goal = goal
        // Don't mark onboarded yet — wait until the AI plan is generated
        // so the user lands on the home screen with personalised targets
        // already in place.
        updated.onboarded = false

        await app.profileService.save(updated)

        // Show the "Building your plan…" full-screen overlay while the AI
        // designs the user's daily nutrition plan.
        withAnimation { generatingPlan = true }
        _ = await app.profileService.generatePlan(for: updated)

        // Mark onboarded only after the plan persists, so RootView won't
        // route to MainTabView until everything is ready.
        if var withPlan = app.profileService.profile ?? Optional(updated) {
            withPlan.onboarded = true
            await app.profileService.save(withPlan)
        }

        // Re-run recipe suggestions now that we have a personalisation
        // profile + AI plan to bias them by.
        await app.recipes.reload(for: app.fridge.items, profile: app.currentProfile, force: true)

        withAnimation { generatingPlan = false }

        // First run lands on the Pro paywall (unless they already subscribe).
        // RootView presents it as a full-screen cover over the main app.
        if !app.store.isPro {
            app.presentingPaywall = true
        }
    }
}

/// Full-screen overlay shown while the AI is building the user's daily
/// nutrition plan. Three rotating sentences hint at what's happening so
/// the wait (typically 4-8 seconds) doesn't feel empty.
private struct PlanGenerationOverlay: View {
    @State private var idx: Int = 0
    private let lines = [
        "Reading your stats…",
        "Designing your daily targets…",
        "Tuning macros for your goal…",
        "Finalising your plan…",
    ]

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle().fill(L.brandBg).frame(width: 110, height: 110)
                    Image(systemName: "sparkles")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(L.brand)
                        .symbolEffect(.pulse.byLayer, options: .repeat(.continuous))
                }
                VStack(spacing: 8) {
                    Text("Building your personalised plan")
                        .font(.manrope(20, .heavy))
                        .kerning(-0.4)
                        .foregroundStyle(L.ink)
                        .multilineTextAlignment(.center)
                    Text(lines[idx])
                        .font(.manrope(13, .heavy))
                        .tracking(0.3)
                        .foregroundStyle(L.muted)
                        .id("line-\(idx)")
                        .transition(.opacity)
                }
                ProgressView()
                    .tint(L.brand)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 32)
        }
        .task {
            // Rotate the sentence every 2s while we wait for the LLM.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    idx = (idx + 1) % lines.count
                }
            }
        }
    }
}

// MARK: - Building blocks

private struct OnbStep<Body: View>: View {
    let title: String
    let sub: String
    @ViewBuilder var content: () -> Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.manrope(28, .heavy))
                    .kerning(-0.7)
                    .foregroundStyle(L.ink)
                Text(sub)
                    .font(.manrope(14, .semibold))
                    .foregroundStyle(L.ink.opacity(0.55))
                    .padding(.bottom, 22)

                content()
            }
            .padding(.horizontal, L.S.pad)
            .padding(.top, 22)
        }
    }
}

private struct OnbCard: View {
    let label: String
    var sub: String? = nil
    var emoji: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let emoji {
                    Text(emoji).font(.system(size: 24))
                        .frame(width: 36)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.manrope(15.5, .heavy))
                        .kerning(-0.2)
                        .foregroundStyle(L.ink)
                    if let sub {
                        Text(sub)
                            .font(.manrope(12.5, .semibold))
                            .foregroundStyle(L.muted)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(selected ? Color.clear : L.muted.opacity(0.4), lineWidth: 1.5)
                    if selected {
                        Circle().fill(L.brand)
                        LSymbol(key: "check", size: 12, weight: .heavy)
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.lg, style: .continuous)
                    .strokeBorder(selected ? L.brand : L.hairline, lineWidth: selected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .modifier(_OnbShadow())
        .tapPress()
    }
}

private struct _OnbShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

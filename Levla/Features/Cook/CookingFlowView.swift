import SwiftUI

/// Full-screen guided cooking view. Pushed when the user taps "Start cooking"
/// on the recipe detail. Replaces the older inline cooking mode where the
/// user had to scroll the detail screen to see the next step.
///
/// Layout:
/// - Top: small back button + progress dots
/// - Middle: ONE step at a time, big, centered, easy to read while
///   cooking. Hero recipe image up top, step number + body underneath.
/// - Bottom: Prev / Next pill on intermediate steps; on the final step
///   the right side becomes a green "Log this meal" CTA that writes the
///   cooked entry and dismisses.
///
/// The detail screen itself no longer logs anything when you tap Start —
/// the only path that writes a `cooked_entries` row is finishing this
/// flow and tapping the green CTA.
struct CookingFlowView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    let recipe: Recipe
    let servings: Int

    @State private var idx: Int = 0
    @State private var logging: Bool = false
    @State private var didLog: Bool = false

    private var steps: [String] { recipe.steps }
    private var isLast: Bool { idx >= steps.count - 1 }

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 12)

                ScrollView {
                    VStack(spacing: 18) {
                        FoodOrb(
                            foods: recipe.uses,
                            color: recipe.color,
                            accent: recipe.accent,
                            height: 220,
                            radius: L.R.xxl,
                            recipe: recipe
                        )
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 12)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(recipe.title)
                                .font(.manrope(20, .heavy))
                                .kerning(-0.4)
                                .foregroundStyle(L.ink)
                                .lineLimit(2)
                            HStack(spacing: 12) {
                                Label("\(servings) serv", systemImage: "person.2.fill")
                                    .font(.manrope(11.5, .heavy))
                                    .foregroundStyle(L.muted)
                                Label("\(recipe.timeMinutes) min", systemImage: "clock.fill")
                                    .font(.manrope(11.5, .heavy))
                                    .foregroundStyle(L.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, L.S.pad)

                        stepCard
                            .padding(.horizontal, L.S.pad)
                            .id("step-\(idx)")
                            .transition(.opacity.combined(with: .move(edge: .trailing)))

                        Color.clear.frame(height: 130)
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: idx)
            }

            VStack { Spacer(); footer }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: { dismiss() }) {
                ZStack {
                    Circle().fill(.white)
                    LSymbol(key: "chevronL", size: 16, weight: .heavy)
                        .foregroundStyle(L.ink)
                }
                .frame(width: 40, height: 40)
                .modifier(_CFShadow())
            }
            .buttonStyle(.plain)

            Spacer()

            // Progress dots — one per step.
            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Capsule()
                        .fill(i == idx ? L.ink : (i < idx ? L.ink.opacity(0.32) : L.ink.opacity(0.12)))
                        .frame(width: i == idx ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.18), value: idx)
                }
            }

            Spacer()
            Spacer().frame(width: 40, height: 40)
        }
    }

    // MARK: - Current step card

    private var stepCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(L.ink)
                Text("\(idx + 1)")
                    .font(.manrope(20, .heavy))
                    .foregroundStyle(L.cream)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text("STEP \(idx + 1) OF \(steps.count)")
                    .font(.manrope(11, .heavy))
                    .tracking(1.2)
                    .foregroundStyle(L.muted)
                Text(idx < steps.count ? steps[idx] : "")
                    .font(.manrope(18, .heavy))
                    .kerning(-0.3)
                    .lineSpacing(4)
                    .foregroundStyle(L.ink)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_CFShadow())
    }

    // MARK: - Footer (prev / next or log)

    private var footer: some View {
        HStack(spacing: 12) {
            // Prev
            Button {
                guard idx > 0 else { return }
                withAnimation { idx -= 1 }
            } label: {
                ZStack {
                    Capsule().fill(.white)
                    HStack(spacing: 6) {
                        LSymbol(key: "chevronL", size: 14, weight: .heavy)
                        Text("Prev")
                    }
                    .font(.manrope(14, .heavy))
                    .foregroundStyle(idx == 0 ? L.muted.opacity(0.5) : L.ink)
                }
                .frame(width: 110, height: L.btnHeight)
            }
            .buttonStyle(.plain)
            .disabled(idx == 0)
            .modifier(_CFShadow())

            // Next or Log meal
            if isLast {
                Button(action: logAndDismiss) {
                    ZStack {
                        Capsule().fill(L.brand)
                        HStack(spacing: 6) {
                            LSymbol(key: "check", size: 14, weight: .heavy)
                            Text(didLog ? "Logged" : (logging ? "Logging…" : "Log this meal"))
                                .tracking(0.6)
                        }
                        .font(.manrope(14, .heavy))
                        .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: L.btnHeight)
                }
                .buttonStyle(.plain)
                .disabled(didLog || logging)
                .shadow(color: L.brand.opacity(0.36), radius: 12, x: 0, y: 6)
            } else {
                Button {
                    withAnimation { idx += 1 }
                } label: {
                    ZStack {
                        Capsule().fill(L.ink)
                        HStack(spacing: 6) {
                            Text("Next step")
                                .tracking(0.6)
                            LSymbol(key: "arrowR", size: 14, weight: .heavy)
                        }
                        .font(.manrope(14, .heavy))
                        .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: L.btnHeight)
                }
                .buttonStyle(.plain)
                .shadow(color: L.ink.opacity(0.22), radius: 12, x: 0, y: 6)
            }
        }
        .padding(.horizontal, L.S.pad)
        .padding(.bottom, 22)
    }

    // MARK: - Logging

    @MainActor
    private func logAndDismiss() {
        guard !logging, !didLog else { return }
        guard let uid = app.auth.currentUserId else { dismiss(); return }
        logging = true
        Task {
            await app.cooked.log(recipe: recipe, servings: servings, userId: uid)
            didLog = true
            logging = false
            // Tiny pause so the user sees the "Logged" confirmation before
            // we close.
            try? await Task.sleep(nanoseconds: 350_000_000)
            dismiss()
        }
    }
}

private struct _CFShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

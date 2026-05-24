import SwiftUI

/// Profile + settings screen. Shows the user's daily targets, lets them
/// tweak weight / activity / goal inline (the fields most likely to shift),
/// and hosts the sign-out button.
///
/// Reached from the user pill in the Home header.
struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 70
    @State private var activity: ActivityLevel = .moderate
    @State private var goal: UserGoal = .maintain
    @State private var saving: Bool = false
    @State private var didLoad = false

    private var displayName: String {
        app.currentProfile?.displayName ?? "You"
    }

    private var email: String {
        if case .signedIn(_, let e) = app.auth.state { return e ?? "" }
        return ""
    }

    private var ageLabel: String {
        if let age = app.currentProfile?.age { return "\(age) yrs" }
        return "—"
    }

    private var heightLabel: String {
        if let h = app.currentProfile?.heightCm { return "\(h) cm" }
        return "—"
    }

    private var kcalLabel: String {
        if let k = app.currentProfile?.dailyKcalGoal { return "\(k) kcal" }
        return "—"
    }

    private var proteinLabel: String {
        if let p = app.currentProfile?.dailyProteinGoal { return "\(p) g" }
        return "—"
    }

    private var carbsLabel: String {
        if let c = app.currentProfile?.dailyCarbsGoal { return "\(c) g" }
        return "—"
    }

    private var fatLabel: String {
        if let f = app.currentProfile?.dailyFatGoal { return "\(f) g" }
        return "—"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard.padding(.top, 8)
                    targetsCard
                    settingsCard
                    signOutButton
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, L.S.pad)
            }
            .background(L.paper.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.manrope(15, .heavy))
                        .foregroundStyle(L.brand)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if saving {
                        ProgressView()
                    }
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let p = app.currentProfile {
                    weight   = p.weightKg ?? 70
                    activity = p.activityLevel ?? .moderate
                    goal     = p.goal ?? .maintain
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(L.brandBg)
                Text(initials(displayName))
                    .font(.manrope(22, .heavy))
                    .foregroundStyle(L.brand)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.manrope(20, .heavy))
                    .kerning(-0.4)
                    .foregroundStyle(L.ink)
                Text(email)
                    .font(.manrope(13, .semibold))
                    .foregroundStyle(L.muted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
        .modifier(_PSoft())
    }

    // MARK: - Daily targets

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Daily targets")

            VStack(spacing: 0) {
                ProfileRow(label: "Calories",  value: kcalLabel)
                Hairline()
                ProfileRow(label: "Protein",   value: proteinLabel)
                Hairline()
                ProfileRow(label: "Carbs",     value: carbsLabel)
                Hairline()
                ProfileRow(label: "Fat",       value: fatLabel)
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )

            Text("Based on Mifflin-St Jeor + your activity & goal. Update anything below and we'll recalculate.")
                .font(.manrope(11.5, .semibold))
                .foregroundStyle(L.muted)
                .padding(.top, 2)
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Personal")

            VStack(spacing: 0) {
                ProfileRow(label: "Age",    value: ageLabel)
                Hairline()
                ProfileRow(label: "Height", value: heightLabel)
                Hairline()

                // Editable: weight
                HStack {
                    Text("Weight")
                        .font(.manrope(15, .heavy))
                        .foregroundStyle(L.ink)
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            weight = max(25, (weight - 0.5))
                            Task { await save() }
                        } label: {
                            LSymbol(key: "minus", size: 14, weight: .heavy)
                                .foregroundStyle(L.ink)
                                .frame(width: 28, height: 28)
                                .background(L.ink.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Text(String(format: "%.1f kg", weight))
                            .font(.manrope(15, .heavy))
                            .foregroundStyle(L.ink)
                            .frame(minWidth: 70)

                        Button {
                            weight = min(350, (weight + 0.5))
                            Task { await save() }
                        } label: {
                            LSymbol(key: "plus", size: 14, weight: .heavy)
                                .foregroundStyle(L.ink)
                                .frame(width: 28, height: 28)
                                .background(L.ink.opacity(0.06), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                Hairline()

                // Editable: activity level
                pickerRow(title: "Activity",
                          selection: $activity,
                          options: ActivityLevel.allCases,
                          label: { $0.displayName })

                Hairline()

                // Editable: goal
                pickerRow(title: "Goal",
                          selection: $goal,
                          options: UserGoal.allCases,
                          label: { $0.displayName })
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func pickerRow<T: Hashable>(
        title: String,
        selection: Binding<T>,
        options: [T],
        label: @escaping (T) -> String
    ) -> some View {
        HStack {
            Text(title)
                .font(.manrope(15, .heavy))
                .foregroundStyle(L.ink)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(label(option)) {
                        selection.wrappedValue = option
                        Task { await save() }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(label(selection.wrappedValue))
                        .font(.manrope(15, .heavy))
                        .foregroundStyle(L.ink)
                    LSymbol(key: "chevronDown", size: 11, weight: .bold)
                        .foregroundStyle(L.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Sign out

    private var signOutButton: some View {
        BigCTA(title: "Sign out", icon: nil, kind: .light) {
            Task {
                await app.auth.signOut()
                dismiss()
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Persistence

    @MainActor
    private func save() async {
        guard let uid = app.auth.currentUserId else { return }
        saving = true
        defer { saving = false }

        let base = app.currentProfile ?? Profile(id: uid)
        var updated = base
        updated.weightKg = (weight * 10).rounded() / 10
        updated.activityLevel = activity
        updated.goal = goal
        updated.onboarded = true

        await app.profileService.save(updated)
        // Re-fetch suggestions since macros / goal changed.
        await app.recipes.reload(for: app.fridge.items, profile: app.currentProfile, force: true)
    }
}

private struct ProfileRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.manrope(15, .heavy))
                .foregroundStyle(L.ink)
            Spacer()
            Text(value)
                .font(.manrope(15, .heavy))
                .foregroundStyle(L.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

private func initials(_ name: String) -> String {
    let parts = name.split(separator: " ")
    let letters = parts.prefix(2).compactMap { $0.first }
    let s = String(letters).uppercased()
    return s.isEmpty ? "U" : s
}

private struct _PSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

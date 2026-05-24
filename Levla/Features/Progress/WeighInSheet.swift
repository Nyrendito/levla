import SwiftUI

/// Sheet shown when the user taps the Weight card on the Progress tab.
/// Records a new weigh-in and lists recent history so they can sanity-check
/// the value against last week.
struct WeighInSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 70
    @State private var didLoad = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, L.S.pad)
                .padding(.top, 14)

            stepper
                .padding(.horizontal, L.S.pad)
                .padding(.top, 18)

            history
                .padding(.horizontal, L.S.pad)
                .padding(.top, 18)

            Spacer(minLength: 12)

            BigCTA(title: app.weightLog.isSaving ? "Saving…" : "Log weight", kind: .ink) {
                Task { await save() }
            }
            .padding(.horizontal, L.S.pad)
            .padding(.bottom, 22)
        }
        .background(L.paper.ignoresSafeArea())
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            weight = app.weightLog.latestKg ?? app.currentProfile?.weightKg ?? 70
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Log your weight")
                .font(.manrope(22, .heavy))
                .kerning(-0.5)
                .foregroundStyle(L.ink)
            Text("Weekly weigh-ins build your Goal Progress chart.")
                .font(.manrope(13, .semibold))
                .foregroundStyle(L.muted)
        }
    }

    private var stepper: some View {
        HStack(spacing: 16) {
            Button { weight = max(25, weight - 0.5) } label: {
                stepIcon(systemName: "minus")
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", weight))
                        .font(.manrope(54, .heavy))
                        .kerning(-1.2)
                        .foregroundStyle(L.ink)
                    Text("kg")
                        .font(.manrope(18, .heavy))
                        .foregroundStyle(L.muted)
                }
                if let kg = app.weightLog.latestKg {
                    let diff = weight - kg
                    Text(diff == 0 ? "Same as last weigh-in" :
                            diff > 0 ? "+\(String(format: "%.1f", diff)) kg vs last" :
                                       "\(String(format: "%.1f", diff)) kg vs last")
                        .font(.manrope(11, .heavy))
                        .tracking(0.2)
                        .foregroundStyle(L.muted)
                }
            }
            .frame(maxWidth: .infinity)

            Button { weight = min(350, weight + 0.5) } label: {
                stepIcon(systemName: "plus")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
    }

    private func stepIcon(systemName: String) -> some View {
        ZStack {
            Circle().fill(L.ink.opacity(0.06))
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(L.ink)
        }
        .frame(width: 50, height: 50)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Recent weigh-ins")

            if app.weightLog.logs.isEmpty {
                Text("No history yet — this will be your first.")
                    .font(.manrope(12.5, .semibold))
                    .foregroundStyle(L.muted)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(app.weightLog.logs.prefix(4).enumerated()), id: \.element.id) { (i, log) in
                        HStack {
                            Text(relativeLabel(log.loggedAt))
                                .font(.manrope(13.5, .heavy))
                                .foregroundStyle(L.ink)
                            Spacer()
                            Text(String(format: "%.1f kg", log.weightKg))
                                .font(.manrope(13.5, .heavy))
                                .foregroundStyle(L.brand)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        if i != min(app.weightLog.logs.count, 4) - 1 {
                            Hairline()
                        }
                    }
                }
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: L.R.lg, style: .continuous)
                        .strokeBorder(L.hairline, lineWidth: 0.5)
                )
            }
        }
    }

    private func relativeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func save() async {
        guard let uid = app.auth.currentUserId else { return }
        await app.weightLog.log(weightKg: weight, userId: uid, profileService: app.profileService)
        dismiss()
    }
}

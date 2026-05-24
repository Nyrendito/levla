import SwiftUI
import UIKit
import AVFoundation

/// Cal-AI / Lifesum style log-a-meal flow.
///
/// Three phases:
/// 1. capture   — full-screen camera viewfinder with a single shutter
/// 2. analyzing — looping progress dots while we hit `analyze-meal`
/// 3. result    — circular hero photo, big kcal headline, stacked macros bar,
///                ingredient list, "Log meal" CTA
struct LogMealView: View {
    let onClose: () -> Void

    @Environment(AppState.self) private var app

    enum Phase: Equatable {
        case instructions   // Cal-AI 3-step pre-camera onboarding
        case capture
        case analyzing
        case result
        case error(String)
    }

    @State private var phase: Phase = .capture
    @State private var capturedImage: UIImage?
    @State private var analysis: AnalyzedMeal?
    @State private var saving = false
    @State private var showLibraryPicker = false

    @AppStorage("hasSeenMealInstructions") private var hasSeenInstructions = false

    var body: some View {
        ZStack {
            L.ink.ignoresSafeArea()

            switch phase {
            case .instructions:
                ScanInstructionsView(
                    steps: ScanInstructionsView.mealSteps,
                    onClose: onClose,
                    onFinish: {
                        hasSeenInstructions = true
                        phase = .capture
                    }
                )

            case .capture:
                LogMealCaptureStage(
                    onClose: onClose,
                    onCaptured: handleCaptured,
                    onLibrary: { showLibraryPicker = true }
                )

            case .analyzing:
                LogMealAnalyzingStage(image: capturedImage)

            case .result:
                if let meal = analysis, let image = capturedImage {
                    LogMealResultStage(
                        image: image,
                        meal: meal,
                        saving: saving,
                        onRetake: { resetToCapture() },
                        onLog: { Task { await logMeal() } }
                    )
                } else {
                    EmptyView()
                }

            case .error(let msg):
                LogMealErrorStage(message: msg, onRetry: { phase = .capture }, onClose: onClose)
            }
        }
        .task {
            if !hasSeenInstructions { phase = .instructions }
        }
        .sheet(isPresented: $showLibraryPicker) {
            LibraryPicker(
                onPicked: { image in
                    showLibraryPicker = false
                    handleCaptured(image)
                },
                onCancel: { showLibraryPicker = false }
            )
        }
    }

    private func handleCaptured(_ image: UIImage) {
        capturedImage = image
        phase = .analyzing
        Task {
            do {
                let meal = try await MealAnalyzer.shared.analyze(image: image)
                if let meal {
                    analysis = meal
                    phase = .result
                } else {
                    phase = .error("Couldn't read the photo. Try again with more light.")
                }
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func resetToCapture() {
        analysis = nil
        capturedImage = nil
        phase = .capture
    }

    @MainActor
    private func logMeal() async {
        guard let meal = analysis, let uid = app.auth.currentUserId, !saving else { return }
        saving = true
        defer { saving = false }
        await app.cooked.logSnapped(meal: meal, userId: uid)
        onClose()
    }
}

// MARK: - Capture

private struct LogMealCaptureStage: View {
    let onClose: () -> Void
    let onCaptured: (UIImage) -> Void
    /// Tapping Library in the bottom mode bar bubbles up so the parent can
    /// present a PHPicker sheet.
    let onLibrary: () -> Void

    @State private var camera = CameraController()
    @State private var flash = false
    @State private var mode: ScanMode = .fridge   // visually-active tab — meal capture uses fridge slot

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.captureSession).ignoresSafeArea()
            } else {
                L.ink.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topChrome
                Spacer()
                helperBanner
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                modeBar
                    .padding(.horizontal, 14)
                    .padding(.bottom, 16)
                shutterRow
                    .padding(.horizontal, 36)
                    .padding(.bottom, 36)
            }

            // Minimalist viewfinder — 4 rounded L-corners hugging the screen.
            CameraCornerBrackets(topInset: 100, bottomInset: 230)

            if flash { Color.white.opacity(0.9).ignoresSafeArea().transition(.opacity) }
        }
        .task {
            await camera.requestAccess()
            await camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var modeBar: some View {
        ScanModeBar(selected: Binding(
            get: { mode },
            set: { newMode in
                // Library bubbles up to parent; everything else stays in-place
                // visually but doesn't change the meal-capture pipeline.
                if newMode == .library {
                    onLibrary()
                } else {
                    mode = newMode
                }
            }
        ))
    }

    private var topChrome: some View {
        HStack {
            Button(action: onClose) {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    LSymbol(key: "close", size: 14, weight: .heavy).foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Log a meal")
                .font(.manrope(15, .heavy))
                .foregroundStyle(.white)
            Spacer()
            Spacer().frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var helperBanner: some View {
        // Compact one-line helper so it doesn't crowd the mode bar / shutter.
        HStack(spacing: 8) {
            AIDot(color: L.brand, size: 8)
            Text("Snap your meal — Levla reads protein, carbs, fat & kcal.")
                .font(.manrope(12.5, .heavy))
                .kerning(-0.1)
                .foregroundStyle(L.cream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(hex: 0x0F0C08).opacity(0.7), in: Capsule())
    }

    private var shutterRow: some View {
        HStack {
            Spacer()
            Button(action: capture) {
                ZStack {
                    Circle().fill(L.cream.opacity(0.18)).frame(width: 84, height: 84)
                    Circle().fill(L.cream)
                        .overlay(Circle().stroke(L.ink, lineWidth: 3))
                        .frame(width: 72, height: 72)
                }
            }
            .buttonStyle(.plain)
            .tapPress()
            Spacer()
        }
    }

    private func capture() {
        Task {
            withAnimation(.easeOut(duration: 0.18)) { flash = true }
            let image = await camera.capturePhoto()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeOut(duration: 0.18)) { flash = false }
            }
            camera.stop()
            if let image { onCaptured(image) }
        }
    }
}

// MARK: - Analyzing

private struct LogMealAnalyzingStage: View {
    let image: UIImage?
    @State private var pulse = false

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            VStack(spacing: 22) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 220)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(.white, lineWidth: 6)
                        )
                        .shadow(color: L.ink.opacity(0.18), radius: 18, x: 0, y: 12)
                        .scaleEffect(pulse ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }

                VStack(spacing: 6) {
                    Text("Analyzing your meal…")
                        .font(.manrope(20, .heavy))
                        .foregroundStyle(L.ink)
                    Text("Identifying ingredients and macros.")
                        .font(.manrope(13.5, .semibold))
                        .foregroundStyle(L.muted)
                }

                ProgressView().tint(L.brand)
            }
        }
        .onAppear { pulse = true }
    }
}

// MARK: - Result

private struct LogMealResultStage: View {
    let image: UIImage
    let meal: AnalyzedMeal
    let saving: Bool
    let onRetake: () -> Void
    let onLog: () -> Void

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header.padding(.top, 14)

                    hero.padding(.top, 20)

                    titleBlock.padding(.top, 20).padding(.horizontal, L.S.pad)

                    kcalBlock.padding(.top, 18).padding(.horizontal, L.S.pad)

                    macroBar.padding(.top, 14).padding(.horizontal, L.S.pad)

                    macroGrid.padding(.top, 16).padding(.horizontal, L.S.pad)

                    if !meal.ingredients.isEmpty {
                        ingredientsList.padding(.top, 24).padding(.horizontal, L.S.pad)
                    }

                    Color.clear.frame(height: 140)
                }
            }

            VStack {
                Spacer()
                BigCTA(title: saving ? "Logging…" : "Log meal", icon: "check", kind: .primary, action: onLog)
                    .padding(.horizontal, L.S.pad)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [L.paper.opacity(0), L.paper.opacity(0.95), L.paper],
                            startPoint: .top, endPoint: .bottom
                        ).ignoresSafeArea(edges: .bottom)
                    )
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onRetake) {
                ZStack {
                    Circle().fill(.white)
                    LSymbol(key: "camera", size: 14, weight: .heavy).foregroundStyle(L.ink)
                }
                .frame(width: 38, height: 38)
                .modifier(_LMSoft())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Your meal")
                .font(.manrope(15, .heavy))
                .tracking(-0.2)
                .foregroundStyle(L.ink)
            Spacer()
            Spacer().frame(width: 38, height: 38)
        }
        .padding(.horizontal, L.S.pad)
    }

    private var hero: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 220, height: 220)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 6))
            .modifier(_LMHero())
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(meal.name)
                .font(.manrope(24, .heavy))
                .kerning(-0.6)
                .foregroundStyle(L.ink)
                .multilineTextAlignment(.center)
            Text(meal.displayConfidence.uppercased())
                .font(.manrope(10, .heavy))
                .tracking(1.4)
                .foregroundStyle(L.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private var kcalBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(meal.kcal)")
                .font(.manrope(56, .heavy))
                .kerning(-1)
                .foregroundStyle(L.ink)
            Text("kcal")
                .font(.manrope(18, .heavy))
                .foregroundStyle(L.muted)
        }
        .frame(maxWidth: .infinity)
    }

    /// Cal AI–style stacked macro bar. Widths weighted by kcal contribution
    /// from each macro: protein/carbs × 4, fat × 9.
    private var macroBar: some View {
        let pKcal = max(0, Double(meal.protein) * 4)
        let cKcal = max(0, Double(meal.carbs)   * 4)
        let fKcal = max(0, Double(meal.fat)     * 9)
        let total = max(1, pKcal + cKcal + fKcal)
        return GeometryReader { proxy in
            HStack(spacing: 2) {
                Capsule().fill(L.macroProtein)
                    .frame(width: max(20, proxy.size.width * pKcal / total))
                Capsule().fill(L.macroCarbs)
                    .frame(width: max(20, proxy.size.width * cKcal / total))
                Capsule().fill(L.macroFat)
                    .frame(width: max(20, proxy.size.width * fKcal / total))
            }
        }
        .frame(height: 12)
    }

    private var macroGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                macroChip(label: "Protein", value: "\(meal.protein)g", color: L.macroProtein)
                macroChip(label: "Carbs",   value: "\(meal.carbs)g",   color: L.macroCarbs)
                macroChip(label: "Fat",     value: "\(meal.fat)g",     color: L.macroFat)
            }
            HStack(spacing: 10) {
                macroChip(label: "Fiber",  value: "\(meal.fiber)g",     color: Color(hex: 0x9A6FCE))
                macroChip(label: "Sugar",  value: "\(meal.sugar)g",     color: Color(hex: 0xE0789B))
                macroChip(label: "Sodium", value: "\(meal.sodium)mg",   color: Color(hex: 0xD49B3E))
            }
        }
    }

    private func macroChip(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label.uppercased())
                    .font(.manrope(10, .heavy))
                    .tracking(1.2)
                    .foregroundStyle(L.muted)
            }
            Text(value)
                .font(.manrope(20, .heavy))
                .kerning(-0.3)
                .foregroundStyle(L.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: L.R.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: L.R.lg, style: .continuous)
                .strokeBorder(L.hairline, lineWidth: 0.5)
        )
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Ingredients")
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(meal.ingredients.enumerated()), id: \.element.id) { (i, ing) in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ing.name)
                                .font(.manrope(15, .heavy))
                                .kerning(-0.2)
                                .foregroundStyle(L.ink)
                            HStack(spacing: 6) {
                                Text("\(ing.protein)P")
                                Text("·").foregroundStyle(L.muted.opacity(0.4))
                                Text("\(ing.carbs)C")
                                Text("·").foregroundStyle(L.muted.opacity(0.4))
                                Text("\(ing.fat)F")
                            }
                            .font(.manrope(12, .semibold))
                            .foregroundStyle(L.muted)
                        }
                        Spacer()
                        Text("\(ing.kcal) kcal")
                            .font(.manrope(13, .heavy))
                            .foregroundStyle(L.ink)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    if i != meal.ingredients.count - 1 {
                        Hairline()
                    }
                }
            }
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: L.R.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: L.R.xl, style: .continuous)
                    .strokeBorder(L.hairline, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Error

private struct LogMealErrorStage: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Hm, that didn't work")
                    .font(.manrope(22, .heavy))
                    .foregroundStyle(L.ink)
                Text(message)
                    .font(.manrope(14, .semibold))
                    .foregroundStyle(L.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                BigCTA(title: "Try again", icon: "camera", kind: .primary, action: onRetry)
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 16)
                Button("Cancel", action: onClose)
                    .font(.manrope(14, .heavy))
                    .foregroundStyle(L.muted)
                    .padding(.top, 4)
            }
        }
    }
}

private struct _LMSoft: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}
private struct _LMHero: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: L.ink.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

import SwiftUI

/// Cal-AI-style 3-step instructions card shown before the camera kicks in.
/// Used by both fridge scanning and meal logging — content is supplied by the
/// caller, layout is identical.
///
/// Top: paginated step numbers (1/2/3) — current one is filled ink, others
/// are pale circles. Below: a hero card with a 'success check + hint' chip,
/// the illustration image, and the mode mini-tabs underneath (decorative
/// only, mirrors what the camera screen will look like). Then a big bold
/// title + tip rows. CTA at the bottom advances or starts the scan.
struct ScanInstructionsView: View {
    let steps: [ScanInstructionStep]
    let onClose: () -> Void
    /// Called when the final step's CTA is tapped — caller should hide the
    /// instructions and transition to the camera.
    let onFinish: () -> Void

    @State private var index: Int = 0

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, L.S.pad)
                    .padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        heroCard
                            .padding(.horizontal, L.S.pad)

                        VStack(alignment: .leading, spacing: 18) {
                            Text(steps[index].title)
                                .font(.manrope(28, .heavy))
                                .kerning(-0.7)
                                .foregroundStyle(L.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("title-\(index)")
                                .transition(.opacity)

                            VStack(spacing: 14) {
                                ForEach(Array(steps[index].tips.enumerated()), id: \.offset) { _, tip in
                                    tipRow(tip)
                                }
                            }
                        }
                        .padding(.horizontal, L.S.pad)
                    }
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                }

                BigCTA(title: ctaTitle, kind: .ink) {
                    advance()
                }
                .padding(.horizontal, L.S.pad)
                .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
    }

    // MARK: - Header (close + paginated step pills)

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                ZStack {
                    Circle().fill(L.ink.opacity(0.06))
                    LSymbol(key: "close", size: 14, weight: .heavy)
                        .foregroundStyle(L.ink)
                }
                .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 10) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.manrope(15, .heavy))
                        .foregroundStyle(i == index ? Color.white : L.ink.opacity(0.5))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(i == index ? L.ink : L.ink.opacity(0.06))
                        )
                        .onTapGesture { withAnimation { index = i } }
                }
            }
        }
    }

    // MARK: - Hero illustration card

    private var heroCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(L.brand)
                    LSymbol(key: "check", size: 12, weight: .heavy)
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)

                Text(steps[index].chipText)
                    .font(.manrope(17, .heavy))
                    .kerning(-0.3)
                    .foregroundStyle(L.ink)
                Spacer(minLength: 0)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            // Stylized illustration area with corner brackets.
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(steps[index].illustrationBg)
                Image(systemName: steps[index].illustrationSymbol)
                    .font(.system(size: 110, weight: .light))
                    .foregroundStyle(steps[index].illustrationTint)
                ViewfinderCornersDecor()
                    .padding(20)
            }
            .frame(height: 260)
            .padding(.horizontal, 18)
            .id("illu-\(index)")
            .transition(.opacity)

            // Decorative mode mini-tabs — mirrors the bar inside the camera.
            HStack(spacing: 8) {
                ForEach(ScanMode.allCases, id: \.self) { mode in
                    decorativeTab(mode: mode, isPrimary: mode == steps[index].emphasizedMode)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(L.ink.opacity(0.04))
        )
    }

    private func decorativeTab(mode: ScanMode, isPrimary: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: mode.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(L.ink.opacity(0.7))
            Text(mode.shortLabel)
                .font(.manrope(9.5, .heavy))
                .tracking(0.1)
                .foregroundStyle(L.ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isPrimary ? L.ink.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Tip rows

    private func tipRow(_ tip: ScanInstructionTip) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(L.ink.opacity(0.05))
                Image(systemName: tip.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(L.ink.opacity(0.85))
            }
            .frame(width: 42, height: 42)

            Text(tip.text)
                .font(.manrope(15.5, .semibold))
                .kerning(-0.2)
                .foregroundStyle(L.ink.opacity(0.65))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Advance

    private var ctaTitle: String {
        if index < steps.count - 1 { return "Next" }
        return steps[index].finalCta
    }

    private func advance() {
        if index < steps.count - 1 {
            withAnimation { index += 1 }
        } else {
            onFinish()
        }
    }
}

// MARK: - Public step model

struct ScanInstructionStep {
    /// Short headline above the chip ("Perfect! Scan now.", "All ingredients visible.")
    let chipText: String
    /// SF Symbol used as the placeholder hero illustration.
    let illustrationSymbol: String
    /// Background tint of the hero card.
    let illustrationBg: Color
    /// Foreground tint of the SF Symbol.
    let illustrationTint: Color
    /// Title of this step.
    let title: String
    /// 2–3 tips shown as small icon + text rows.
    let tips: [ScanInstructionTip]
    /// Which mode tab to emphasize on this step's decorative bar.
    let emphasizedMode: ScanMode
    /// Label of the CTA on this step if it's the last step (e.g. "Scan now").
    let finalCta: String
}

struct ScanInstructionTip {
    let systemImage: String
    let text: String
}

// MARK: - Mode enum (shared with ScanModeBar / refactored ScanFlowView)

/// The four ways a user can add things to their fridge from the unified scan
/// camera. Mode lives as @State inside the camera so the user can tap a tab
/// to switch — no back-and-forth through the bottom sheet.
enum ScanMode: String, CaseIterable, Hashable {
    case fridge, receipt, barcode, library

    var label: String {
        switch self {
        case .fridge:  return "Scan fridge"
        case .receipt: return "Scan receipt"
        case .barcode: return "Barcode"
        case .library: return "Library"
        }
    }

    /// Truncated for narrow decorative tab pills.
    var shortLabel: String {
        switch self {
        case .fridge:  return "Fridge"
        case .receipt: return "Receipt"
        case .barcode: return "Barcode"
        case .library: return "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .fridge:  return "refrigerator.fill"
        case .receipt: return "doc.text.fill"
        case .barcode: return "barcode"
        case .library: return "photo.on.rectangle.angled"
        }
    }

    var scanKind: ScanKind? {
        switch self {
        case .fridge:  return .fridge
        case .receipt: return .receipt
        case .barcode: return .barcode
        case .library: return nil   // library is its own pipeline
        }
    }
}

// MARK: - Viewfinder corners (lighter version used inside the instructions card)

struct ViewfinderCornersDecor: View {
    var body: some View {
        VStack {
            HStack { corner(.tl); Spacer(); corner(.tr) }
            Spacer()
            HStack { corner(.bl); Spacer(); corner(.br) }
        }
        .allowsHitTesting(false)
    }

    private enum P { case tl, tr, bl, br }
    private func corner(_ a: P) -> some View {
        let path = Path { p in
            switch a {
            case .tl: p.move(to: .init(x: 0, y: 24)); p.addLine(to: .zero); p.addLine(to: .init(x: 24, y: 0))
            case .tr: p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 24, y: 0)); p.addLine(to: .init(x: 24, y: 24))
            case .bl: p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 0, y: 24)); p.addLine(to: .init(x: 24, y: 24))
            case .br: p.move(to: .init(x: 0, y: 24)); p.addLine(to: .init(x: 24, y: 24)); p.addLine(to: .init(x: 24, y: 0))
            }
        }
        return path.stroke(L.ink.opacity(0.55), lineWidth: 2).frame(width: 24, height: 24)
    }
}

// MARK: - Pre-baked step packs

extension ScanInstructionsView {
    /// Three-step intro shown before fridge scanning. The final CTA is
    /// "Scan now" and lands on the camera with the fridge mode active.
    static let fridgeSteps: [ScanInstructionStep] = [
        ScanInstructionStep(
            chipText: "Perfect! Scan now.",
            illustrationSymbol: "refrigerator",
            illustrationBg: L.brandBg,
            illustrationTint: L.brand,
            title: "Capture the whole fridge",
            tips: [
                .init(systemImage: "viewfinder", text: "Open the door wide and fit every shelf in frame."),
                .init(systemImage: "rectangle.inset.filled", text: "Don't crop the sides — drawers count too."),
                .init(systemImage: "sun.max.fill", text: "Bright, even lighting beats glossy reflections."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "All items visible.",
            illustrationSymbol: "carrot.fill",
            illustrationBg: L.popBg,
            illustrationTint: L.pop,
            title: "Show every item",
            tips: [
                .init(systemImage: "hand.point.up.left.fill", text: "Pull items forward if they're hiding behind others."),
                .init(systemImage: "tag.fill", text: "Keep brand labels facing the camera when you can."),
                .init(systemImage: "wind", text: "Wipe condensation — fogged shelves confuse the model."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "Receipt & library is best",
            illustrationSymbol: "doc.text",
            illustrationBg: L.sunBg,
            illustrationTint: L.sunFg,
            title: "Any doubts? Receipts…",
            tips: [
                .init(systemImage: "doc.text.magnifyingglass",
                      text: "When possible, snap your grocery receipt — Levla reads the exact items and quantities for near-100% accuracy."),
                .init(systemImage: "camera.viewfinder",
                      text: "Our fridge scan is best right after you've stocked up and want a quick capture without typing anything."),
            ],
            emphasizedMode: .receipt,
            finalCta: "Scan now"
        ),
    ]

    /// Three-step intro shown before logging a meal photo.
    static let mealSteps: [ScanInstructionStep] = [
        ScanInstructionStep(
            chipText: "Perfect! Scan now.",
            illustrationSymbol: "fork.knife",
            illustrationBg: L.brandBg,
            illustrationTint: L.brand,
            title: "Capture the full meal",
            tips: [
                .init(systemImage: "viewfinder", text: "Fit the entire plate inside the scan lines."),
                .init(systemImage: "rectangle.inset.filled", text: "Don't cut off the sides of the meal."),
                .init(systemImage: "sun.max.fill", text: "Bright, even lighting helps the model identify each component."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "All ingredients visible.",
            illustrationSymbol: "leaf.fill",
            illustrationBg: L.popBg,
            illustrationTint: L.pop,
            title: "Show every ingredient",
            tips: [
                .init(systemImage: "square.stack.3d.up.fill", text: "Spread out layered food — burgers, wraps, bowls."),
                .init(systemImage: "trash.fill", text: "Remove foil, lids, or packaging that hides what's inside."),
                .init(systemImage: "circle.dotted", text: "Top-down works best when there's a sauce or topping."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "Receipt is best",
            illustrationSymbol: "doc.text",
            illustrationBg: L.sunBg,
            illustrationTint: L.sunFg,
            title: "Any doubts? Receipts…",
            tips: [
                .init(systemImage: "doc.text.magnifyingglass",
                      text: "If you bought it pre-made, scan the receipt instead — Levla reads the exact item and gets macros from the label."),
                .init(systemImage: "camera.viewfinder",
                      text: "Photo logging is best for home-cooked meals where you don't know the exact ingredient amounts."),
            ],
            emphasizedMode: .receipt,
            finalCta: "Scan now"
        ),
    ]
}

import SwiftUI

/// Cal-AI-style 3-step instructions shown before the camera kicks in. Layout
/// is fixed (no scrolling on any phone size 16+) — each step fits the
/// available height by giving the hero card a flexible frame.
///
/// Top: close + paginated step pills (1/2/3, current is filled).
/// Middle: hero card (chip + illustration with corner brackets) → flexes.
/// Below: bold title + 2 tip rows with small icons.
/// Bottom: Next / Scan now CTA.
struct ScanInstructionsView: View {
    let steps: [ScanInstructionStep]
    let onClose: () -> Void
    let onFinish: () -> Void

    @State private var index: Int = 0

    var body: some View {
        ZStack {
            L.paper.ignoresSafeArea()

            GeometryReader { proxy in
                VStack(spacing: 14) {
                    header
                        .padding(.horizontal, L.S.pad)
                        .padding(.top, 12)

                    heroCard
                        .padding(.horizontal, L.S.pad)
                        // Hero takes up to ~42% of available height so the
                        // tip rows are guaranteed visible underneath.
                        .frame(maxHeight: proxy.size.height * 0.42)

                    tipBlock
                        .padding(.horizontal, L.S.pad)

                    Spacer(minLength: 12)

                    BigCTA(title: ctaTitle, kind: .ink) { advance() }
                        .padding(.horizontal, L.S.pad)
                        .padding(.bottom, 24)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                ZStack {
                    Circle().fill(L.ink.opacity(0.06))
                    LSymbol(key: "close", size: 13, weight: .heavy).foregroundStyle(L.ink)
                }
                .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Text("\(i + 1)")
                        .font(.manrope(14, .heavy))
                        .foregroundStyle(i == index ? Color.white : L.ink.opacity(0.55))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(i == index ? L.ink : L.ink.opacity(0.06)))
                        .onTapGesture { withAnimation { index = i } }
                }
            }
        }
    }

    // MARK: - Hero card (chip + illustration)

    private var heroCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(L.brand)
                    LSymbol(key: "check", size: 10, weight: .heavy).foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)

                Text(steps[index].chipText)
                    .font(.manrope(15, .heavy))
                    .kerning(-0.2)
                    .foregroundStyle(L.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.top, 14)
            .padding(.horizontal, 16)

            // Illustration area — flexes to fill remaining hero height.
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(steps[index].illustrationBg)

                Image(systemName: steps[index].illustrationSymbol)
                    .font(.system(size: 78, weight: .light))
                    .foregroundStyle(steps[index].illustrationTint)

                CornerMarks()
                    .padding(20)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(L.ink.opacity(0.04))
        )
        .id("hero-\(index)")
        .transition(.opacity)
    }

    // MARK: - Title + tips

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(steps[index].title)
                .font(.manrope(26, .heavy))
                .kerning(-0.6)
                .foregroundStyle(L.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .id("title-\(index)")
                .transition(.opacity)
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(Array(steps[index].tips.enumerated()), id: \.offset) { _, tip in
                    tipRow(tip)
                }
            }
        }
    }

    private func tipRow(_ tip: ScanInstructionTip) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle().fill(L.ink.opacity(0.05))
                Image(systemName: tip.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(L.ink.opacity(0.85))
            }
            .frame(width: 36, height: 36)

            Text(tip.text)
                .font(.manrope(13.5, .semibold))
                .kerning(-0.1)
                .foregroundStyle(L.ink.opacity(0.65))
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - CTA / advance

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

// MARK: - Step model

struct ScanInstructionStep {
    let chipText: String
    let illustrationSymbol: String
    let illustrationBg: Color
    let illustrationTint: Color
    let title: String
    let tips: [ScanInstructionTip]
    /// Kept for back-compat; not rendered inside the hero anymore.
    let emphasizedMode: ScanMode
    let finalCta: String
}

struct ScanInstructionTip {
    let systemImage: String
    let text: String
}

// MARK: - Mode enum (shared with ScanModeBar / refactored ScanFlowView)

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
        case .library: return nil
        }
    }
}

// MARK: - Small inner corner marks for the illustration card

private struct CornerMarks: View {
    var body: some View {
        VStack {
            HStack { mark(.tl); Spacer(); mark(.tr) }
            Spacer()
            HStack { mark(.bl); Spacer(); mark(.br) }
        }
        .allowsHitTesting(false)
    }
    private enum P { case tl, tr, bl, br }
    private func mark(_ a: P) -> some View {
        Path { p in
            switch a {
            case .tl: p.move(to: .init(x: 0, y: 20)); p.addLine(to: .zero); p.addLine(to: .init(x: 20, y: 0))
            case .tr: p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 20, y: 0)); p.addLine(to: .init(x: 20, y: 20))
            case .bl: p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: 0, y: 20)); p.addLine(to: .init(x: 20, y: 20))
            case .br: p.move(to: .init(x: 0, y: 20)); p.addLine(to: .init(x: 20, y: 20)); p.addLine(to: .init(x: 20, y: 0))
            }
        }
        .stroke(L.ink.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        .frame(width: 20, height: 20)
    }
}

// MARK: - Pre-baked step packs

extension ScanInstructionsView {
    static let fridgeSteps: [ScanInstructionStep] = [
        ScanInstructionStep(
            chipText: "Perfect! Scan now.",
            illustrationSymbol: "refrigerator",
            illustrationBg: L.brandBg,
            illustrationTint: L.brand,
            title: "Capture the whole fridge",
            tips: [
                .init(systemImage: "viewfinder", text: "Fit every shelf in frame — door wide open."),
                .init(systemImage: "sun.max.fill", text: "Even lighting beats glossy reflections."),
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
                .init(systemImage: "tag.fill", text: "Keep brand labels facing the camera."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "Receipts work best.",
            illustrationSymbol: "doc.text",
            illustrationBg: L.sunBg,
            illustrationTint: L.sunFg,
            title: "Any doubts? Receipts…",
            tips: [
                .init(systemImage: "doc.text.magnifyingglass",
                      text: "Snap a grocery receipt for near-100% accuracy — exact items, exact quantities."),
                .init(systemImage: "camera.viewfinder",
                      text: "Fridge scan is best for quick captures right after stocking up."),
            ],
            emphasizedMode: .receipt,
            finalCta: "Scan now"
        ),
    ]

    static let mealSteps: [ScanInstructionStep] = [
        ScanInstructionStep(
            chipText: "Perfect! Scan now.",
            illustrationSymbol: "fork.knife",
            illustrationBg: L.brandBg,
            illustrationTint: L.brand,
            title: "Capture the full meal",
            tips: [
                .init(systemImage: "viewfinder", text: "Fit the whole plate inside the frame."),
                .init(systemImage: "sun.max.fill", text: "Bright, even lighting helps with portion size."),
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
                .init(systemImage: "trash.fill", text: "Remove foil, lids, or anything hiding what's inside."),
            ],
            emphasizedMode: .fridge,
            finalCta: "Next"
        ),
        ScanInstructionStep(
            chipText: "Receipts are exact.",
            illustrationSymbol: "doc.text",
            illustrationBg: L.sunBg,
            illustrationTint: L.sunFg,
            title: "Any doubts? Receipts…",
            tips: [
                .init(systemImage: "doc.text.magnifyingglass",
                      text: "Pre-made or take-out? Snap the receipt — Levla reads the exact item & macros."),
                .init(systemImage: "camera.viewfinder",
                      text: "Photo logging is best for home-cooked plates where the recipe is in your head."),
            ],
            emphasizedMode: .receipt,
            finalCta: "Scan now"
        ),
    ]
}

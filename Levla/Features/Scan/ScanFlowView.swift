import SwiftUI
import AVFoundation
import UIKit

/// Full-screen scan flow — three modes, dispatched by `ScanKind`.
///
/// - .fridge   → multi-shelf capture → GPT-4o vision → verify
/// - .receipt  → single capture → Apple Vision OCR → GPT-4.1-mini → verify
/// - .barcode  → live detection → Open Food Facts lookup → verify
struct ScanFlowView: View {
    @Environment(AppState.self) private var app
    let kind: ScanKind
    let onClose: () -> Void

    enum Phase: Equatable {
        case capture           // camera viewfinder
        case identifying       // calling the LLM / OCR
        case verify            // candidates list
        case error(String)
    }

    @State private var phase: Phase = .capture
    @State private var candidates: [ScanCandidate] = []
    @State private var decisions: [UUID: Decision] = [:]

    enum Decision { case yes, no }

    var body: some View {
        ZStack {
            L.ink.ignoresSafeArea()

            switch (kind, phase) {
            case (.fridge, .capture):
                FridgeRecordingStage(onClose: onClose, onDone: runFridgeAI)
                    .ignoresSafeArea()

            case (.receipt, .capture):
                SinglePhotoCaptureStage(kind: .receipt, onClose: onClose, onCaptured: runReceiptAI)
                    .ignoresSafeArea()

            case (.barcode, .capture):
                LiveBarcodeStage(onClose: onClose, onDetect: runBarcodeLookup)
                    .ignoresSafeArea()

            case (_, .identifying):
                IdentifyingStage(kind: kind, items: candidates)

            case (_, .verify):
                VerifyStage(
                    kind: kind, candidates: $candidates, decisions: $decisions,
                    onClose: onClose, onConfirm: commit
                )

            case (_, .error(let message)):
                ErrorStage(message: message, onRetry: { phase = .capture }, onClose: onClose)
            }
        }
    }

    // MARK: - AI dispatchers

    private func runFridgeAI(_ images: [UIImage]) {
        guard !images.isEmpty else {
            phase = .error("No frames captured — try recording again.")
            return
        }
        phase = .identifying
        Task {
            do {
                candidates = try await AIScanService.shared.scanFridge(images: images)
                try? await Task.sleep(nanoseconds: 250_000_000)
                phase = .verify
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func runReceiptAI(_ image: UIImage) {
        phase = .identifying
        Task {
            do {
                let text = await VisionRecognizer.extractReceiptText(image)
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    phase = .error("Couldn't read any text on the receipt — try again with more light.")
                    return
                }
                candidates = try await AIScanService.shared.parseReceipt(text: text)
                try? await Task.sleep(nanoseconds: 250_000_000)
                phase = .verify
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    private func runBarcodeLookup(_ code: String) {
        phase = .identifying
        Task {
            do {
                if let item = try await AIScanService.shared.lookupBarcode(code) {
                    candidates = [item]
                } else {
                    candidates = [ScanCandidate(
                        foodKey: "milk", displayName: "Unknown product · \(code)",
                        qty: "1", confidence: 0.3, category: .pantry, daysLeft: 30
                    )]
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
                phase = .verify
            } catch {
                phase = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Commit

    private func commit() {
        guard let userId = app.auth.currentUserId else { onClose(); return }

        let items: [FoodItem] = candidates.compactMap { c in
            guard decisions[c.id] != .no else { return nil }
            return FoodItem(
                userId: userId,
                name: c.displayName,
                foodKey: c.foodKey,
                category: c.category,
                qty: c.qty,
                daysLeft: c.daysLeft,
                source: source(for: kind)
            )
        }
        if !items.isEmpty {
            Task { await app.fridge.add(items) }
        }
        onClose()
    }

    private func source(for kind: ScanKind) -> AddSource {
        switch kind { case .fridge: return .scan; case .receipt: return .receipt; case .barcode: return .scan }
    }
}

// MARK: - Fridge recording (sweep-the-fridge UX → multiple stills under the hood)

private struct FridgeRecordingStage: View {
    let onClose: () -> Void
    let onDone: ([UIImage]) -> Void

    @State private var sampler = VideoFrameSampler()
    @State private var stopping = false

    #if targetEnvironment(simulator)
    private let isSimulator = true
    #else
    private let isSimulator = false
    #endif

    var body: some View {
        ZStack {
            if sampler.isAuthorized {
                SamplerPreview(session: sampler.captureSession).ignoresSafeArea()
            } else {
                CameraPermissionMessage()
            }

            // Subtle scrim so the red dot + close button stay legible.
            LinearGradient(
                colors: [Color.black.opacity(0.45), .clear, .clear, Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                TopChrome(title: "", onClose: onClose)

                if isSimulator {
                    SimulatorWarning()
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                }

                // The only "you are recording" affordance — pulsing red dot + timer.
                if sampler.isSampling {
                    RecordingPill(seconds: sampler.elapsedSeconds)
                        .padding(.top, 10)
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Text(helperText)
                    .font(.manrope(15, .bold))
                    .foregroundStyle(L.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 22)

                RecordButton(isRecording: sampler.isSampling) {
                    handleTap()
                }
                .padding(.bottom, 36)
            }
        }
        .task {
            await sampler.requestAccess()
            await sampler.start()
            // Auto-ship the moment the sampler hits maxFrames so the user
            // never lands in a "stopped, now what?" state.
            sampler.onAutoComplete = {
                finishAndSend()
            }
        }
        .onDisappear { sampler.stop() }
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: sampler.isSampling)
    }

    private var helperText: String {
        if stopping {
            return "Analyzing your fridge…"
        }
        if !sampler.isSampling {
            if sampler.sampledFrames.isEmpty {
                return "Tap to record. Slowly sweep your fridge — shelves and drawers."
            } else {
                return "Tap to send what you've got."
            }
        }
        return "Recording. Sweep slowly — Levla's watching."
    }

    /// One unified tap handler so we never hit a dead-button state:
    /// - sampling now            → stop & send
    /// - stopped, have frames    → send what we've got
    /// - stopped, no frames      → start a fresh recording
    private func handleTap() {
        if sampler.isSampling {
            finishAndSend()
        } else if !sampler.sampledFrames.isEmpty {
            finishAndSend()
        } else {
            sampler.startSampling()
        }
    }

    private func finishAndSend() {
        guard !stopping else { return }
        stopping = true
        sampler.stopSampling()
        // Tiny pause so the model has the very last frame in the buffer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDone(sampler.sampledFrames)
        }
    }
}

/// Shown only when running in the iOS Simulator — explains why the camera
/// preview is black and frames aren't being captured.
private struct SimulatorWarning: View {
    var body: some View {
        HStack(spacing: 10) {
            LSymbol(key: "bolt", size: 14, weight: .heavy).foregroundStyle(L.sun)
            Text("Simulator has no camera — run on a real device to scan.")
                .font(.manrope(12, .heavy))
                .kerning(-0.1)
                .foregroundStyle(L.cream)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(L.sun.opacity(0.4), lineWidth: 0.5))
    }
}

/// iOS-Camera-style record button: solid red disc → red square inside ring.
private struct RecordButton: View {
    let isRecording: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .stroke(L.cream, lineWidth: 4)
                    .frame(width: 78, height: 78)
                if isRecording {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0xE53935))
                        .frame(width: 32, height: 32)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .fill(Color(hex: 0xE53935))
                        .frame(width: 60, height: 60)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isRecording)
        }
        .buttonStyle(.plain)
        .tapPress()
    }
}

/// Just a red dot + elapsed timer — no frame counter, no thumbnails.
/// Looks like a standard video-recording indicator.
private struct RecordingPill: View {
    let seconds: Double
    @State private var blink = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: 0xE53935))
                .frame(width: 10, height: 10)
                .opacity(blink ? 0.35 : 1.0)
                .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: blink)
                .onAppear { blink = true }
            Text(timeString)
                .font(.mono(14))
                .foregroundStyle(L.cream)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color.black.opacity(0.5), in: Capsule())
        .overlay(Capsule().stroke(L.cream.opacity(0.15), lineWidth: 0.5))
    }

    private var timeString: String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Single photo capture (receipt)

private struct SinglePhotoCaptureStage: View {
    let kind: ScanKind
    let onClose: () -> Void
    let onCaptured: (UIImage) -> Void

    @State private var camera = CameraController()
    @State private var flash = false

    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.captureSession).ignoresSafeArea()
            } else {
                CameraPermissionMessage()
            }

            VStack(spacing: 0) {
                TopChrome(title: title, onClose: onClose)
                Spacer()
                HelperBanner(text: helperText)
                    .padding(.horizontal, 22)
                shutterRow
                    .padding(.horizontal, 36)
                    .padding(.bottom, 30)
            }
            ViewfinderCorners().padding(60)
            if flash { Color.white.opacity(0.9).ignoresSafeArea().transition(.opacity) }
        }
        .task {
            await camera.requestAccess()
            await camera.start()
        }
        .onDisappear { camera.stop() }
    }

    private var title: String {
        switch kind {
        case .fridge:  return "Scan fridge"
        case .receipt: return "Scan receipt"
        case .barcode: return "Scan"
        }
    }

    private var helperText: String {
        switch kind {
        case .fridge:  return "Open the door wide. One shot of the whole fridge — Levla handles the rest."
        case .receipt: return "Hold the receipt flat in the frame."
        case .barcode: return ""
        }
    }

    private var shutterRow: some View {
        HStack {
            Spacer()
            Button(action: capture) {
                ZStack {
                    Circle().fill(L.cream.opacity(0.18)).frame(width: 78, height: 78)
                    Circle().fill(L.cream)
                        .overlay(Circle().stroke(L.ink, lineWidth: 3))
                        .frame(width: 66, height: 66)
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

// MARK: - Live barcode

private struct LiveBarcodeStage: View {
    let onClose: () -> Void
    let onDetect: (String) -> Void

    @State private var scanner = BarcodeScanner()
    @State private var detected: String?

    var body: some View {
        ZStack {
            if scanner.isAuthorized {
                BarcodePreview(session: scanner.captureSession).ignoresSafeArea()
            } else {
                CameraPermissionMessage()
            }

            VStack(spacing: 0) {
                TopChrome(title: "Scan barcode", onClose: onClose)
                Spacer()
                HelperBanner(text: detected.map { "Code: \($0)" } ?? "Center the barcode in the frame. We'll do the rest.")
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
            }
            BarcodeFrame()
                .padding(60)
        }
        .task {
            await scanner.requestAccess()
            scanner.onDetect = { code in
                guard detected == nil else { return }
                detected = code
                onDetect(code)
            }
            await scanner.start()
        }
        .onDisappear { scanner.stop() }
    }
}

private struct BarcodeFrame: View {
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(L.cream.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                    .frame(height: 180)
                Rectangle()
                    .fill(L.pop)
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Identifying state

private struct IdentifyingStage: View {
    let kind: ScanKind
    let items: [ScanCandidate]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1612), Color(hex: 0x0E0B08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                Spacer().frame(height: 120)
                Text(kind == .barcode ? "LOOKING UP" : "IDENTIFYING")
                    .font(.mono(11)).tracking(0.8)
                    .foregroundStyle(L.cream.opacity(0.55))

                if kind == .barcode {
                    Text("Resolving product…")
                        .font(.manrope(34, .heavy)).kerning(-1.1)
                        .foregroundStyle(L.cream)
                } else {
                    Text(kind == .receipt ? "Parsing receipt." : "Reading shelves.")
                        .font(.manrope(36, .heavy)).kerning(-1.2)
                        .foregroundStyle(L.cream)
                }

                HStack(spacing: 8) {
                    ProgressView().tint(L.cream.opacity(0.6))
                    Text(kind == .receipt ? "Apple Vision → GPT-4.1-mini" :
                         kind == .fridge ? "GPT-4o is looking at your fridge" :
                                           "Open Food Facts")
                        .font(.manrope(13, .bold))
                        .foregroundStyle(L.cream.opacity(0.6))
                }
                .padding(.top, 14)

                Spacer()
            }
            .padding(.horizontal, 26)
        }
    }
}

// MARK: - Verify stage

private struct VerifyStage: View {
    let kind: ScanKind
    @Binding var candidates: [ScanCandidate]
    @Binding var decisions: [UUID: ScanFlowView.Decision]
    let onClose: () -> Void
    let onConfirm: () -> Void

    private var confirmedCount: Int {
        candidates.filter { decisions[$0.id] != .no }.count
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            L.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(kind == .barcode ? "PRODUCT FOUND" : "JUST CHECKING")
                            .font(.mono(11)).tracking(0.8)
                            .foregroundStyle(L.ink.opacity(0.4))
                        if candidates.isEmpty {
                            Text("Nothing found.")
                                .font(.manrope(34, .heavy)).kerning(-1.1)
                                .foregroundStyle(L.ink)
                        } else {
                            Text(kind == .barcode
                                 ? "Add to your fridge?"
                                 : "\(candidates.count) item\(candidates.count == 1 ? "" : "s")\nto confirm.")
                                .font(.manrope(34, .heavy)).kerning(-1.1)
                                .foregroundStyle(L.ink)
                        }
                        HStack(spacing: 8) {
                            AIDot(color: L.mint, size: 7)
                            Text(kind == .receipt ? "Receipt parsed by GPT-4.1-mini" :
                                 kind == .fridge ? "Fridge analyzed by GPT-4o" :
                                                   "Matched from Open Food Facts")
                                .font(.manrope(13, .semibold))
                                .foregroundStyle(L.ink.opacity(0.55))
                        }
                    }
                    .padding(.top, 110)

                    VStack(spacing: 12) {
                        ForEach(candidates) { card in
                            VerifyCard(
                                card: card,
                                decision: decisions[card.id]
                            ) { decision in
                                decisions[card.id] = decision
                            }
                        }
                    }

                    if candidates.isEmpty {
                        Text("Try again with better light, or add an item by hand.")
                            .font(.manrope(13.5, .semibold))
                            .foregroundStyle(L.ink.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    }
                }
                .padding(.horizontal, L.S.pad)
                .padding(.bottom, 160)
            }

            BigCTA(
                title: candidates.isEmpty ? "Done" : "Add \(confirmedCount) to my fridge",
                icon: candidates.isEmpty ? nil : "fridge",
                kind: .primary,
                action: onConfirm
            )
            .padding(.horizontal, 18)
            .padding(.bottom, 24)

            VStack {
                HStack {
                    Button(action: onClose) {
                        ZStack {
                            Circle().fill(.white)
                            LSymbol(key: "close", size: 18, weight: .heavy).foregroundStyle(L.ink)
                        }
                        .frame(width: 40, height: 40)
                        .modifier(_VerifyChromeShadow())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.top, 52)
                Spacer()
            }
        }
    }
}

private struct VerifyCard: View {
    let card: ScanCandidate
    let decision: ScanFlowView.Decision?
    let onDecide: (ScanFlowView.Decision) -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                FoodTile(food: card.foodKey, size: 52, radius: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.displayName)
                        .font(.manrope(16, .heavy))
                        .kerning(-0.3)
                        .foregroundStyle(L.ink)
                    HStack(spacing: 6) {
                        Text(card.qty)
                            .font(.manrope(12.5, .semibold))
                            .foregroundStyle(L.ink.opacity(0.5))
                        Text("· \(Int(card.confidence * 100))% sure")
                            .font(.manrope(12.5, .semibold))
                            .foregroundStyle(L.ink.opacity(0.35))
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Button { onDecide(.no) } label: {
                    HStack(spacing: 6) {
                        LSymbol(key: "close", size: 16, weight: .heavy)
                        Text("Not there")
                    }
                    .font(.manrope(14, .heavy))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(L.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(L.ink)
                }
                .buttonStyle(.plain)

                Button { onDecide(.yes) } label: {
                    HStack(spacing: 6) {
                        LSymbol(key: "check", size: 16, weight: .heavy)
                        Text("Yes, got it")
                    }
                    .font(.manrope(14, .heavy))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(L.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(L.cream)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(_VerifyShadow())
        .opacity(decision == .no ? 0.45 : 1)
        .animation(.easeOut(duration: 0.2), value: decision)
    }
}

// MARK: - Error stage

private struct ErrorStage: View {
    let message: String
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            L.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Spacer().frame(height: 120)
                Text("THAT DIDN'T WORK")
                    .font(.mono(11)).tracking(0.8)
                    .foregroundStyle(L.ink.opacity(0.4))
                Text("Couldn't finish the scan.")
                    .font(.manrope(34, .heavy)).kerning(-1.1)
                    .foregroundStyle(L.ink)
                Text(message)
                    .font(.manrope(14, .medium))
                    .lineSpacing(3)
                    .foregroundStyle(L.ink.opacity(0.6))
            }
            .padding(.horizontal, L.S.pad)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                BigCTA(title: "Try again", kind: .primary, action: onRetry)
                Button("Close", action: onClose)
                    .font(.manrope(14, .heavy))
                    .foregroundStyle(L.ink.opacity(0.6))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Shared chrome

private struct TopChrome: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                ZStack { Circle().fill(L.cream.opacity(0.12)); LSymbol(key: "close", size: 18, weight: .heavy).foregroundStyle(L.cream) }
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.manrope(15, .heavy))
                .kerning(-0.3)
                .foregroundStyle(L.cream)
            Spacer()
            ZStack { Circle().fill(L.cream.opacity(0.12)); LSymbol(key: "bolt", size: 18, weight: .semibold).foregroundStyle(L.cream) }
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.top, 52)
    }
}

private struct HelperBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            AIDot(color: L.pop, size: 8)
            Text(text)
                .font(.manrope(12.5, .heavy))
                .kerning(-0.1)
                .foregroundStyle(L.cream)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(hex: 0x0F0C08).opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CameraPermissionMessage: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0E0B08).ignoresSafeArea()
            VStack(spacing: 14) {
                LSymbol(key: "camera", size: 44, weight: .semibold).foregroundStyle(L.cream.opacity(0.7))
                Text("Allow camera access to scan.")
                    .font(.manrope(15, .semibold)).foregroundStyle(L.cream.opacity(0.7))
                BigCTA(title: "Open Settings", kind: .pop) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .frame(maxWidth: 240)
            }
        }
    }
}

private struct ViewfinderCorners: View {
    var body: some View {
        VStack {
            HStack { corner(.topLeading); Spacer(); corner(.topTrailing) }
            Spacer()
            HStack { corner(.bottomLeading); Spacer(); corner(.bottomTrailing) }
        }
        .allowsHitTesting(false)
    }

    private enum CornerPosition { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    private func corner(_ a: CornerPosition) -> some View {
        let shape = Path { p in
            switch a {
            case .topLeading:
                p.move(to: CGPoint(x: 0, y: 32)); p.addLine(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 32, y: 0))
            case .topTrailing:
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 32, y: 0)); p.addLine(to: CGPoint(x: 32, y: 32))
            case .bottomLeading:
                p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: 32)); p.addLine(to: CGPoint(x: 32, y: 32))
            case .bottomTrailing:
                p.move(to: CGPoint(x: 0, y: 32)); p.addLine(to: CGPoint(x: 32, y: 32)); p.addLine(to: CGPoint(x: 32, y: 0))
            }
        }
        return shape.stroke(L.cream, lineWidth: 3).frame(width: 32, height: 32)
    }
}

private struct _VerifyShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.card(content) }
}
private struct _VerifyChromeShadow: ViewModifier {
    func body(content: Content) -> some View { L.Shadow.soft(content) }
}

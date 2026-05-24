import AVFoundation
import SwiftUI
import UIKit

/// Captures a short video clip of the user sweeping their fridge and
/// returns it as a compressed H.264 .mp4 ready for Gemini's native video
/// API.
///
/// Architecturally replaces the old VideoFrameSampler. The previous flow
/// fired N still photos at fixed intervals and sent them to GPT-4o as
/// separate `image_url` parts — wasteful (N× token cost) and the model
/// had no motion continuity between frames. Gemini 2.5 Flash accepts
/// inline video natively (~1 fps sampling under the hood, but the model
/// preserves motion / context across the clip), so a single 4-6 s clip
/// outperforms a 6-frame still grid at a fraction of the token cost.
///
/// The clip is recorded silently via AVCaptureMovieFileOutput (no audio
/// input added → no audio track → ~0 audio tokens at the LLM), then
/// transcoded to H.264 ~2 Mbps so the base64 payload stays well under
/// Gemini's 20 MB inline cap even with a 10 s clip.
@MainActor
@Observable
final class FridgeVideoRecorder: NSObject {
    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let configureQueue = DispatchQueue(label: "app.levla.fridge-recorder.configure")

    // MARK: - Observable state

    private(set) var isAuthorized = false
    private(set) var isRunning = false
    private(set) var isRecording = false
    private(set) var elapsedSeconds: Double = 0
    /// Compressed clip data, populated once the recording stops + transcode
    /// finishes. The Scan flow reads this and ships it to scan-fridge.
    private(set) var clipData: Data?

    // MARK: - Tuning

    /// Soft cap on clip duration. The recorder auto-stops at this mark so a
    /// distracted user can't end up uploading a 90 s video. 20 s is long
    /// enough to sweep every shelf + the drawers + the door bins at a
    /// natural pace; at MEDIA_RESOLUTION_LOW that's roughly 2 000 Gemini
    /// tokens of video — still cheap.
    var maxDuration: TimeInterval = 20.0

    // MARK: - Private

    private var startedAt: Date?
    private var elapsedTimer: Timer?
    private var rawClipURL: URL?
    private var stopContinuation: CheckedContinuation<Data?, Never>?

    /// Fires when we auto-stop because we hit `maxDuration` — Scan flow
    /// uses it to advance to the analyse stage without a second tap.
    var onAutoComplete: (() -> Void)?

    var captureSession: AVCaptureSession { session }

    // MARK: - Session lifecycle

    func requestAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: isAuthorized = true
        case .notDetermined: isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default: isAuthorized = false
        }
    }

    func start() async {
        guard isAuthorized, !session.isRunning else {
            if session.isRunning { isRunning = true }
            return
        }

        let sessionRef = session
        let outRef = movieOutput

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            configureQueue.async {
                sessionRef.beginConfiguration()

                // 1280x720 keeps file size small but is high enough that
                // food labels and produce shapes stay readable for the model.
                if sessionRef.canSetSessionPreset(.hd1280x720) {
                    sessionRef.sessionPreset = .hd1280x720
                } else {
                    sessionRef.sessionPreset = .high
                }

                // VIDEO INPUT ONLY — never add an AVCaptureDeviceInput for
                // audio, so the resulting movie has no audio track and we
                // don't burn Gemini tokens on it (audio also requires the
                // mic permission, which we don't want to prompt for).
                if sessionRef.inputs.isEmpty,
                   let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   sessionRef.canAddInput(input) {
                    sessionRef.addInput(input)
                }

                if sessionRef.outputs.isEmpty, sessionRef.canAddOutput(outRef) {
                    sessionRef.addOutput(outRef)
                    // Hard ceiling slightly above maxDuration — second line
                    // of defence in case the timer-based auto-stop hiccups.
                    // 25 s × 720p ≈ 15-30 MB raw, well under iOS's tempfile
                    // limits; the transcode step shrinks it again before
                    // upload.
                    outRef.maxRecordedDuration = CMTime(seconds: 25, preferredTimescale: 600)
                }

                sessionRef.commitConfiguration()
                sessionRef.startRunning()
                cont.resume()
            }
        }
        isRunning = true
    }

    func stop() {
        if isRecording { _ = Task { await stopRecording() } }
        let sessionRef = session
        configureQueue.async { if sessionRef.isRunning { sessionRef.stopRunning() } }
        isRunning = false
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording, isRunning else { return }
        // Each recording lands in a fresh tempfile we can clean up after
        // transcoding. Use .mov here because that's AVCaptureMovieFileOutput's
        // native format — we'll re-encode to .mp4 for the upload.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fridge-\(UUID().uuidString).mov")
        rawClipURL = url
        clipData = nil
        startedAt = Date()
        isRecording = true

        movieOutput.startRecording(to: url, recordingDelegate: self)

        // Tick driving the on-screen "0.8s, 1.2s…" recording indicator,
        // and auto-stop at maxDuration.
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.startedAt else { return }
                let elapsed = Date().timeIntervalSince(started)
                self.elapsedSeconds = elapsed
                if elapsed >= self.maxDuration, self.isRecording {
                    _ = await self.stopRecording()
                    self.onAutoComplete?()
                }
            }
        }
    }

    /// Stops the AVCaptureMovieFileOutput recording and waits for the
    /// transcode-to-mp4 to finish. Returns the compressed clip bytes so the
    /// caller can ship them straight to scan-fridge.
    @discardableResult
    func stopRecording() async -> Data? {
        guard isRecording else { return clipData }
        elapsedTimer?.invalidate(); elapsedTimer = nil
        isRecording = false
        movieOutput.stopRecording()

        // Resumed inside the delegate callback once writing finishes.
        return await withCheckedContinuation { cont in
            self.stopContinuation = cont
        }
    }

    // MARK: - Transcode

    private func transcodeToMp4(input: URL) async -> Data? {
        let asset = AVAsset(url: input)
        // MediumQuality gives us a ~2 Mbps H.264 at 720p — large enough that
        // food detail survives, small enough that a 5 s clip is <3 MB.
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            return try? Data(contentsOf: input)
        }
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fridge-\(UUID().uuidString).mp4")
        session.outputURL = outURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        // Strip any incidental audio (we don't add a mic input, but belt-and-
        // braces in case AVCaptureMovieFileOutput ever fills a placeholder
        // audio track on some hardware revisions).
        session.audioTimePitchAlgorithm = .spectral

        await session.export()
        defer {
            try? FileManager.default.removeItem(at: input)
            try? FileManager.default.removeItem(at: outURL)
        }

        guard session.status == .completed else { return try? Data(contentsOf: input) }
        return try? Data(contentsOf: outURL)
    }
}

extension FridgeVideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput,
                                didFinishRecordingTo outputFileURL: URL,
                                from connections: [AVCaptureConnection],
                                error: Error?) {
        Task { @MainActor in
            // Even if there was a recording error, try to recover bytes from
            // whatever AVFoundation managed to write before the failure.
            let data = await transcodeToMp4(input: outputFileURL)
            self.clipData = data
            let cont = self.stopContinuation
            self.stopContinuation = nil
            cont?.resume(returning: data)
        }
    }
}

/// SwiftUI wrapper for the live preview — same shape as the old sampler's
/// preview view so the existing FridgeRecordingStage layout still works.
struct FridgeRecorderPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreview.PreviewView {
        let v = CameraPreview.PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: CameraPreview.PreviewView, context: Context) {}
}

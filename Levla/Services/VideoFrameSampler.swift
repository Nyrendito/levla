import AVFoundation
import SwiftUI
import UIKit
import CoreImage

/// Looks and feels like recording video — but under the hood we sample one
/// still frame at a fixed interval and hand the batch to the LLM. This is
/// the "press once, sweep your fridge" UX powering the Scan-fridge flow.
///
/// We can't use `AVCapturePhotoOutput` here because it would play the shutter
/// sound 5-8 times in a row, which kills the immersive feel. Instead we use
/// `AVCaptureVideoDataOutput` (silent) and grab CGImages from the buffer.
@MainActor
@Observable
final class VideoFrameSampler: NSObject {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let configureQueue = DispatchQueue(label: "app.levla.framesampler.configure")
    private let bufferQueue = DispatchQueue(label: "app.levla.framesampler.buffer")
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - Observable state

    private(set) var isAuthorized = false
    private(set) var isRunning = false
    private(set) var isSampling = false
    private(set) var sampledFrames: [UIImage] = []
    private(set) var elapsedSeconds: Double = 0

    // MARK: - Tuning

    /// Time between samples while recording. Long enough to give the user
    /// time to open a drawer / move to the next shelf, short enough that a
    /// ~15 s sweep produces 5-6 distinct frames.
    var sampleInterval: TimeInterval = 3.0
    /// Hard cap on frames sent to the model. 6 × 1024px JPEGs ≈ 1.2 MB on the wire.
    var maxFrames: Int = 6

    // MARK: - Private

    private var latestCGImage: CGImage?
    private var sampleTimer: Timer?
    private var elapsedTimer: Timer?
    private var startedAt: Date?

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
        let outRef = videoOutput
        let bufferQueueRef = bufferQueue
        let delegate = self

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            configureQueue.async {
                sessionRef.beginConfiguration()

                // .hd1280x720 keeps payload small but still readable for the model.
                if sessionRef.canSetSessionPreset(.hd1280x720) {
                    sessionRef.sessionPreset = .hd1280x720
                } else {
                    sessionRef.sessionPreset = .high
                }

                if sessionRef.inputs.isEmpty,
                   let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   sessionRef.canAddInput(input) {
                    sessionRef.addInput(input)
                }

                if sessionRef.outputs.isEmpty, sessionRef.canAddOutput(outRef) {
                    outRef.alwaysDiscardsLateVideoFrames = true
                    outRef.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    outRef.setSampleBufferDelegate(delegate, queue: bufferQueueRef)
                    sessionRef.addOutput(outRef)
                }

                sessionRef.commitConfiguration()
                sessionRef.startRunning()
                cont.resume()
            }
        }
        isRunning = true
    }

    func stop() {
        stopSampling()
        let sessionRef = session
        configureQueue.async { if sessionRef.isRunning { sessionRef.stopRunning() } }
        isRunning = false
    }

    // MARK: - Sampling

    func startSampling() {
        guard !isSampling else { return }
        sampledFrames = []
        elapsedSeconds = 0
        startedAt = Date()
        isSampling = true

        // Initial frame fired immediately so the user sees feedback.
        captureNextFrame()

        // Subsequent frames every `sampleInterval` seconds.
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.captureNextFrame() }
        }

        // 100ms tick just for the live timer / progress UI.
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let started = self.startedAt else { return }
                self.elapsedSeconds = Date().timeIntervalSince(started)
            }
        }
    }

    func stopSampling() {
        sampleTimer?.invalidate(); sampleTimer = nil
        elapsedTimer?.invalidate(); elapsedTimer = nil
        isSampling = false
    }

    func removeFrame(at index: Int) {
        guard sampledFrames.indices.contains(index) else { return }
        sampledFrames.remove(at: index)
    }

    func reset() {
        stopSampling()
        sampledFrames.removeAll()
        elapsedSeconds = 0
        startedAt = nil
    }

    private func captureNextFrame() {
        guard sampledFrames.count < maxFrames else { stopSampling(); return }
        guard let cg = latestCGImage else { return }
        sampledFrames.append(UIImage(cgImage: cg))
        if sampledFrames.count >= maxFrames { stopSampling() }
    }
}

extension VideoFrameSampler: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixel)

        // Render to a CGImage off the main thread. The video frame buffer
        // is reused by AVCaptureVideoDataOutput, so we MUST detach a copy.
        let contextLocal = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = contextLocal.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            self.latestCGImage = cg
        }
    }
}

/// SwiftUI wrapper for the live preview.
struct SamplerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreview.PreviewView {
        let v = CameraPreview.PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: CameraPreview.PreviewView, context: Context) {}
}

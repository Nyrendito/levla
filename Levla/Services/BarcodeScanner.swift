import AVFoundation
import SwiftUI
import UIKit

/// Live barcode scanner using `AVCaptureMetadataOutput` — way faster than
/// running `VNDetectBarcodesRequest` on every frame, since the OS does the
/// detection in dedicated hardware.
@MainActor
@Observable
final class BarcodeScanner: NSObject {
    private let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "app.levla.barcode")

    private(set) var isAuthorized = false
    private(set) var isRunning = false
    private(set) var lastDetectedCode: String?

    /// Called when a barcode is recognized. Returns true to keep scanning,
    /// false to stop the session.
    var onDetect: ((String) -> Void)?

    /// `AVCaptureMetadataOutput` will keep firing for the same code; we use
    /// this to dedupe so we don't hammer the lookup endpoint.
    private var recentlySeen: String?
    private var recentlySeenAt: Date = .distantPast

    var captureSession: AVCaptureSession { session }

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
        let outRef = metadataOutput
        let queueRef = queue
        let delegate = self
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queueRef.async {
                sessionRef.beginConfiguration()

                if sessionRef.inputs.isEmpty,
                   let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   sessionRef.canAddInput(input) {
                    sessionRef.addInput(input)
                }

                if sessionRef.outputs.isEmpty, sessionRef.canAddOutput(outRef) {
                    sessionRef.addOutput(outRef)
                    // Attach delegate on the main queue — its callback is @MainActor.
                    outRef.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
                    outRef.metadataObjectTypes = [
                        .ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .pdf417,
                    ]
                }

                sessionRef.commitConfiguration()
                sessionRef.startRunning()
                cont.resume()
            }
        }
        isRunning = true
    }

    func stop() {
        let sessionRef = session
        queue.async { if sessionRef.isRunning { sessionRef.stopRunning() } }
        isRunning = false
    }
}

extension BarcodeScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        let first = metadataObjects.compactMap { $0 as? AVMetadataMachineReadableCodeObject }.first
        guard let raw = first?.stringValue else { return }
        Task { @MainActor in
            // Dedupe — same barcode within 2 seconds is a no-op.
            if raw == self.recentlySeen, Date().timeIntervalSince(self.recentlySeenAt) < 2 { return }
            self.recentlySeen = raw
            self.recentlySeenAt = Date()
            self.lastDetectedCode = raw
            self.onDetect?(raw)
        }
    }
}

/// SwiftUI wrapper for the barcode camera preview.
struct BarcodePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreview.PreviewView {
        let v = CameraPreview.PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: CameraPreview.PreviewView, context: Context) {}
}

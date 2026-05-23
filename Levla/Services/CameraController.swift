import AVFoundation
import SwiftUI
import UIKit

/// Wraps an AVCaptureSession + still-image output for the scan screens.
/// The session runs in the background and delivers a single UIImage when
/// `capturePhoto()` is called.
@MainActor
@Observable
final class CameraController: NSObject {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "app.levla.camera")

    private(set) var isAuthorized = false
    private(set) var isRunning = false
    private(set) var lastImage: UIImage?

    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    var captureSession: AVCaptureSession { session }

    func requestAccess() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    func start() async {
        guard isAuthorized else { return }
        guard !session.isRunning else { isRunning = true; return }

        let sessionRef = session
        let outputRef = output

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                sessionRef.beginConfiguration()
                sessionRef.sessionPreset = .photo

                if sessionRef.inputs.isEmpty,
                   let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   sessionRef.canAddInput(input) {
                    sessionRef.addInput(input)
                }

                if sessionRef.outputs.isEmpty, sessionRef.canAddOutput(outputRef) {
                    sessionRef.addOutput(outputRef)
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

    func capturePhoto() async -> UIImage? {
        guard isAuthorized, session.isRunning else { return nil }
        return await withCheckedContinuation { cont in
            self.captureContinuation = cont
            let settings = AVCapturePhotoSettings()
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let image: UIImage? = {
            if let data = photo.fileDataRepresentation() { return UIImage(data: data) }
            return nil
        }()
        Task { @MainActor in
            self.lastImage = image
            self.captureContinuation?.resume(returning: image)
            self.captureContinuation = nil
        }
    }
}

/// SwiftUI wrapper for the live camera preview.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

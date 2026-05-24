import SwiftUI
import PhotosUI

/// Thin SwiftUI wrapper around PHPickerViewController. Used by the Library
/// mode of the unified scan camera so the user can pick an existing photo
/// instead of taking a new one — same downstream pipeline.
///
/// The view itself is invisible; it's presented from a parent via `.sheet`.
/// When the user picks an image, `onPicked` fires with the decoded UIImage
/// and the sheet auto-dismisses. Cancel fires `onCancel`.
struct LibraryPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: LibraryPicker
        init(_ parent: LibraryPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [parent] image, _ in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        parent.onPicked(image)
                    } else {
                        parent.onCancel()
                    }
                }
            }
        }
    }
}

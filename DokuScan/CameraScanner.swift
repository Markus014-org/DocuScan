import SwiftUI
import VisionKit

struct CameraScanner: UIViewControllerRepresentable {
    var onScanned: ([UIImage]) -> Void
    var onCancel: () -> Void
    var onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let owner: CameraScanner
        init(owner: CameraScanner) { self.owner = owner }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            owner.onScanned(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            owner.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            owner.onFailure(error.localizedDescription)
        }
    }
}

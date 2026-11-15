import SwiftUI
import MessageUI

struct MailComposer: UIViewControllerRepresentable {
    let fileURL: URL
    let recipient: String
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([recipient])
        composer.setSubject(fileURL.deletingPathExtension().lastPathComponent)
        if let bytes = try? Data(contentsOf: fileURL) {
            composer.addAttachmentData(bytes, mimeType: "application/pdf", fileName: fileURL.lastPathComponent)
        }
        return composer
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            onFinish()
        }
    }
}

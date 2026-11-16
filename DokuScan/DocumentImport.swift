import Foundation
import UIKit
import PDFKit
import UniformTypeIdentifiers

// PDFs werden für die neue OCR zunächst als Bilder gerendert.
// Maximal 30 Seiten pro Import, um Speicherprobleme zu begrenzen.
enum DocumentImport {
    static func load(urls: [URL]) throws -> [UIImage] {
        var images: [UIImage] = []
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "pdf" || PDFDocument(data: data) != nil {
                guard let document = PDFDocument(data: data), document.pageCount > 0 else {
                    throw UserFacingError(message: "Die PDF lässt sich nicht öffnen: \(url.lastPathComponent)")
                }
                for number in 0..<document.pageCount {
                    guard images.count < 30 else { break }
                    if let page = document.page(at: number) {
                        let bounds = page.bounds(for: .mediaBox)
                        let factor = min(2.0, 1800 / max(1, max(bounds.width, bounds.height)))
                        let size = CGSize(width: max(1, bounds.width * factor), height: max(1, bounds.height * factor))
                        images.append(page.thumbnail(of: size, for: .mediaBox).pixelsUpright())
                    }
                }
            } else if let image = UIImage(data: data) {
                images.append(image.pixelsUpright())
            } else {
                throw UserFacingError(message: "Dateiformat nicht unterstützt: \(url.lastPathComponent)")
            }
            if images.count >= 30 { break }
        }
        guard !images.isEmpty else { throw UserFacingError(message: "Keine Bild- oder PDF-Seiten gefunden.") }
        return images
    }
}

import UIKit
import CoreText

/// A4 bei 72 Punkt/Zoll, mit unsichtbarer, durchsuchbarer OCR-Textebene.
enum PDFCreator {
    static let a4 = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)

    static func create(pages: [ScannedPage], quality: PDFQuality = .balanced,
                       appearance: ScanAppearance = .automatic,
                       originalPageIDs: Set<UUID> = []) throws -> Data {
        guard !pages.isEmpty else { throw UserFacingError(message: "Es wurde keine Seite gescannt.") }
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Scanchris",
            kCGPDFContextTitle as String: "Scanchris OCR PDF"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: a4, format: format)
        return renderer.pdfData { rendererContext in
            for page in pages {
                rendererContext.beginPage()
                let image = preparedImage(page.image, quality: quality, appearance: appearance,
                                          useOriginal: originalPageIDs.contains(page.id))
                let size = image.size
                guard size.width > 0, size.height > 0 else { continue }
                let scale = min(a4.width / size.width, a4.height / size.height)
                let rect = CGRect(
                    x: (a4.width - size.width * scale) / 2,
                    y: (a4.height - size.height * scale) / 2,
                    width: size.width * scale,
                    height: size.height * scale
                )
                image.draw(in: rect)
                let context = rendererContext.cgContext
                for segment in page.segments {
                    drawInvisibleText(segment, in: rect, context: context)
                }
            }
        }
    }

    /// Der gleiche Verarbeitungspfad dient der Vorschau und der PDF-Ausgabe.
    /// „Original“ darf niemals frühere Schwärzungen rückgängig machen:
    /// source ist ausschließlich das aktuelle, bereits bearbeitete Scanbild.
    static func preparedImage(_ source: UIImage, quality: PDFQuality,
                              appearance: ScanAppearance, useOriginal: Bool) -> UIImage {
        let upright = source.pixelsUpright()
        // Original heißt keine Bildverbesserung; die separat gewählte PDF-Größe
        // gilt auch hier. Zuschnitte, Drehungen und Schwärzungen bleiben erhalten.
        let enhanced = useOriginal ? upright : DocumentEnhancer.process(upright, mode: appearance)
        // Schwarz-Weiß darf nicht erneut als JPEG kodiert werden, weil damit
        // an den zuvor binarisierten Schriftkanten graue Artefakte entstünden.
        if appearance == .blackWhite && !useOriginal { return enhanced }
        // Die verlustfreie Wahl vermeidet weitere Resampling-/JPEG-Schritte.
        // Die interne Kompression des PDF-Renderers bleibt Sache von Core Graphics.
        guard quality != .lossless else { return enhanced }
        let maxSide = max(enhanced.size.width, enhanced.size.height)
        let factor = min(1, quality.maxDimension / max(1, maxSide))
        let size = CGSize(width: max(1, enhanced.size.width * factor), height: max(1, enhanced.size.height * factor))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            enhanced.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: quality.compression),
              let image = UIImage(data: jpeg) else { return resized }
        return image
    }

    private static func drawInvisibleText(_ segment: OCRSegment, in imageRect: CGRect, context: CGContext) {
        let box = segment.boundingBox
        guard !segment.text.isEmpty, box.width > 0.001, box.height > 0.001 else { return }
        let x = imageRect.minX + box.minX * imageRect.width
        let y = imageRect.minY + (1 - box.maxY) * imageRect.height
        let desiredWidth = box.width * imageRect.width
        let fontSize = max(4, min(42, box.height * imageRect.height * 0.86))
        let attr = NSAttributedString(string: segment.text, attributes: [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: fontSize)
        ])
        let line = CTLineCreateWithAttributedString(attr)
        let measuredWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        guard measuredWidth > 0 else { return }
        context.saveGState()
        context.translateBy(x: x, y: y + fontSize)
        // CoreText benutzt eine nach oben gerichtete y-Achse, UIKit nach unten.
        context.scaleBy(x: desiredWidth / measuredWidth, y: -1)
        context.textMatrix = .identity
        context.setTextDrawingMode(.invisible)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

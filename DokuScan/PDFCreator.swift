import UIKit
import CoreText

/// A4 bei 72 Punkt/Zoll, mit unsichtbarer, durchsuchbarer OCR-Textebene.
enum PDFCreator {
    static let a4 = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)

    static func create(pages: [ScannedPage]) throws -> Data {
        guard !pages.isEmpty else { throw UserFacingError(message: "Es wurde keine Seite gescannt.") }
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "DokuScan",
            kCGPDFContextTitle as String: "DokuScan OCR PDF"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: a4, format: format)
        return renderer.pdfData { rendererContext in
            for page in pages {
                rendererContext.beginPage()
                let image = page.image.pixelsUpright()
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

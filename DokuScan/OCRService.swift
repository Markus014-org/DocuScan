import Foundation
import UIKit
import Vision

extension UIImage {
    /// Dreht Bildpixel in die sichtbare Orientierung; wichtig für Crop und Vision.
    func pixelsUpright() -> UIImage {
        if imageOrientation == .up, cgImage != nil { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

enum OCRService {
    /// Vision erkennt Text vollständig lokal auf dem iPhone (kein OCR-Server).
    static func recognize(_ images: [UIImage]) async throws -> [[OCRSegment]] {
        try await Task.detached(priority: .userInitiated) {
            try images.map { image in
                let upright = image.pixelsUpright()
                guard let cgImage = upright.cgImage else {
                    throw UserFacingError(message: "Ein gescanntes Bild konnte nicht gelesen werden.")
                }
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["de-DE", "en-US"]
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.006
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
                let lines = (request.results ?? []).compactMap { observation -> OCRSegment? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return OCRSegment(text: candidate.string, boundingBox: observation.boundingBox)
                }
                // Oben nach unten, innerhalb einer Zeile links nach rechts.
                return lines.sorted {
                    let d = abs($0.boundingBox.midY - $1.boundingBox.midY)
                    if d > 0.018 { return $0.boundingBox.midY > $1.boundingBox.midY }
                    return $0.boundingBox.minX < $1.boundingBox.minX
                }
            }
        }.value
    }
}

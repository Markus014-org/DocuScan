import UIKit
import CoreImage

/// Bildaufbereitung erst für Vorschau / Export. OCR und Scanbild bleiben unverändert.
/// Alle Modi laufen vollständig lokal auf dem iPhone.
enum DocumentEnhancer {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func process(_ image: UIImage, mode: ScanAppearance) -> UIImage {
        let original = image.pixelsUpright()
        guard mode != .original, let cg = original.cgImage else { return original }

        if mode == .blackWhite {
            return adaptiveBlackWhite(cg) ?? original
        }
        var result = CIImage(cgImage: cg)
        // Rauschen vor dem Schärfen reduzieren, um Körnung nicht zu verstärken.
        if let filter = CIFilter(name: "CINoiseReduction") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.015, forKey: "inputNoiseLevel")
            filter.setValue(0.35, forKey: "inputSharpness")
            result = filter.outputImage ?? result
        }
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(mode == .grayscale ? 0.0 : 0.87, forKey: kCIInputSaturationKey)
            filter.setValue(mode == .grayscale ? 1.28 : 1.35, forKey: kCIInputContrastKey)
            filter.setValue(mode == .grayscale ? 0.025 : 0.045, forKey: kCIInputBrightnessKey)
            result = filter.outputImage ?? result
        }
        if let filter = CIFilter(name: "CIUnsharpMask") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.7, forKey: kCIInputRadiusKey)
            filter.setValue(0.30, forKey: kCIInputIntensityKey)
            result = filter.outputImage ?? result
        }
        guard let output = context.createCGImage(result, from: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)) else {
            return original
        }
        return UIImage(cgImage: output, scale: 1, orientation: .up)
    }

    /// Lokal adaptive Schwelle: Papier wird weiß, Druck dunkel.
    /// Separable Boxfilter-Mittelwerte brauchen nur O(Bildbreite) Zusatzspeicher.
    /// Für feinen Thermodruck kann die Originalansicht die bessere Wahl sein.
    private static func adaptiveBlackWhite(_ source: CGImage) -> UIImage? {
        let width = source.width, height = source.height
        guard width > 0, height > 0, width <= 12000, height <= 12000,
              width <= 35_000_000 / height else { return nil }
        let graySpace = CGColorSpaceCreateDeviceGray()
        var luminance = [UInt8](repeating: 0, count: width * height)
        let drawn = luminance.withUnsafeMutableBytes { memory -> Bool in
            guard let ctx = CGContext(data: memory.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: graySpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let radius = max(12, min(42, min(width, height) / 90))
        var output = [UInt8](repeating: 255, count: width * height)
        var sums = [Int](repeating: 0, count: width)
        for y in 0...min(radius, height - 1) {
            for x in 0..<width { sums[x] += Int(luminance[y * width + x]) }
        }
        for y in 0..<height {
            if y > 0 {
                let remove = y - radius - 1
                if remove >= 0 {
                    for x in 0..<width { sums[x] -= Int(luminance[remove * width + x]) }
                }
                let add = y + radius
                if add < height {
                    for x in 0..<width { sums[x] += Int(luminance[add * width + x]) }
                }
            }
            let rows = min(height - 1, y + radius) - max(0, y - radius) + 1
            var sum = 0
            for x in 0...min(radius, width - 1) { sum += sums[x] }
            for x in 0..<width {
                if x > 0 {
                    if x - radius - 1 >= 0 { sum -= sums[x - radius - 1] }
                    if x + radius < width { sum += sums[x + radius] }
                }
                let cols = min(width - 1, x + radius) - max(0, x - radius) + 1
                let mean = sum / max(1, rows * cols)
                // Dunkle Pixel nur unterhalb der lokalen Papierhelligkeit erhalten.
                output[y * width + x] = Int(luminance[y * width + x]) < mean - 10 ? 0 : 255
            }
        }
        // 1 Bit pro Pixel statt eines RGB-Bildes: weiße Flächen brauchen
        // praktisch keine Bilddaten, und es entstehen keine JPEG-Artefakte.
        let rowBytes = (width + 7) / 8
        var packed = [UInt8](repeating: 0, count: rowBytes * height)
        for y in 0..<height {
            for x in 0..<width where output[y * width + x] == 255 {
                packed[y * rowBytes + x / 8] |= UInt8(0x80 >> (x % 8))
            }
        }
        let data = Data(packed)
        guard let provider = CGDataProvider(data: data as CFData),
              let cg = CGImage(width: width, height: height, bitsPerComponent: 1,
                               bitsPerPixel: 1, bytesPerRow: rowBytes,
                               space: graySpace,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                               provider: provider, decode: nil,
                               shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

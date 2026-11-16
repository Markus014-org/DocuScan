import UIKit

// Schnelle heuristische Qualitätswarnungen, keine automatische Verwerfung eines Scans.
enum ImageQuality {
    static func warnings(for image: UIImage) -> [String] {
        let img = image.pixelsUpright()
        var findings: [String] = []
        if min(img.size.width, img.size.height) < 900 {
            findings.append("Geringe Auflösung – kleiner Text könnte schlecht erkannt werden.")
        }
        let w = 96, h = 96
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let cg = img.cgImage else { return findings }
        let space = CGColorSpaceCreateDeviceRGB()
        let result = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let ctx = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard result else { return findings }
        var mean = 0.0, edges = 0.0, contrast = 0.0
        var luminance = [Double](repeating: 0, count: w * h)
        for index in 0..<(w*h) {
            let i = index * 4
            luminance[index] = 0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i+1]) + 0.0722 * Double(pixels[i+2])
            mean += luminance[index]
        }
        mean /= Double(w*h)
        for y in 1..<h-1 { for x in 1..<w-1 {
            let i = y*w+x
            let g = abs(luminance[i]-luminance[i-1]) + abs(luminance[i]-luminance[i-w])
            edges += g
            contrast += abs(luminance[i]-mean)
        } }
        let count = Double((w-2)*(h-2))
        if mean < 58 { findings.append("Sehr dunkle Aufnahme – bessere Beleuchtung versuchen.") }
        if mean > 247 { findings.append("Sehr helle Aufnahme – möglicherweise überbelichtet.") }
        if edges / count < 8 && contrast / count < 24 {
            findings.append("Wenig Kontrast oder unscharfe Aufnahme – bitte Text überprüfen.")
        }
        return findings
    }
}

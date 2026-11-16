import SwiftUI

// Schwarze Schwärzung wird direkt in die Bildpixel gezeichnet (nicht nur als PDF-Annotation).
// Anschließend läuft OCR erneut, damit kein alter verdeckter Text in die PDF-Suche gelangt.
struct RedactionView: View {
    let original: UIImage
    let onApply: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var current: UIImage
    @State private var start: CGPoint?
    @State private var end: CGPoint?
    @State private var count = 0

    init(original: UIImage, onApply: @escaping (UIImage) -> Void) {
        self.original = original
        self.onApply = onApply
        _current = State(initialValue: original.pixelsUpright())
    }

    var body: some View {
        GeometryReader { geometry in
            let fitted = imageRect(in: geometry.size)
            ZStack {
                Color.black.opacity(0.06)
                Image(uiImage: current)
                    .resizable()
                    .frame(width: fitted.width, height: fitted.height)
                    .position(x: fitted.midX, y: fitted.midY)
                if let a = start, let b = end {
                    let box = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
                    Rectangle().fill(Color.black.opacity(0.9))
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 5)
                .onChanged { value in
                    start = start ?? clamp(value.startLocation, in: fitted)
                    end = clamp(value.location, in: fitted)
                }
                .onEnded { _ in
                    guard let a = start, let b = end else { return }
                    let box = CGRect(x: min(a.x,b.x), y: min(a.y,b.y), width: abs(a.x-b.x), height: abs(a.y-b.y)).intersection(fitted)
                    if box.width > 4 && box.height > 4 {
                        let x = (box.minX - fitted.minX) * current.size.width / fitted.width
                        let y = (box.minY - fitted.minY) * current.size.height / fitted.height
                        let w = box.width * current.size.width / fitted.width
                        let h = box.height * current.size.height / fitted.height
                        let format = UIGraphicsImageRendererFormat()
                        format.scale = 1
                        format.opaque = true
                        current = UIGraphicsImageRenderer(size: current.size, format: format).image { context in
                            current.draw(in: CGRect(origin: .zero, size: current.size))
                            context.cgContext.setFillColor(UIColor.black.cgColor)
                            context.cgContext.fill(CGRect(x: x, y: y, width: w, height: h))
                        }
                        count += 1
                    }
                    start = nil
                    end = nil
                })
        }
        .safeAreaInset(edge: .bottom) {
            Text("Mit dem Finger Rechtecke über vertrauliche Angaben ziehen. Schwärzungen werden endgültig in die Bildpixel übernommen.")
                .font(.footnote).padding(12).background(.regularMaterial)
        }
        .navigationTitle("Schwärzen (\(count))")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Übernehmen") { onApply(current); dismiss() }.disabled(count == 0)
            }
        }
    }

    private func imageRect(in size: CGSize) -> CGRect {
        let scale = min(size.width / max(1, current.size.width), size.height / max(1, current.size.height))
        let width = current.size.width * scale, height = current.size.height * scale
        return CGRect(x: (size.width - width)/2, y: (size.height - height)/2, width: width, height: height)
    }
    private func clamp(_ pt: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: min(rect.maxX,max(rect.minX,pt.x)), y: min(rect.maxY,max(rect.minY,pt.y)))
    }
}

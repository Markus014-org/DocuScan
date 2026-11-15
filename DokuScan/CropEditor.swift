import SwiftUI

/// Normalisierte Zuschneidegrenzen, über vier Eckpunkte per Finger veränderbar.
struct CropEditor: View {
    @Environment(\.dismiss) private var dismiss
    let original: UIImage
    let onSave: (UIImage) -> Void
    @State private var crop = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Ziehe die vier türkisfarbenen Ecken auf den gewünschten Bildausschnitt.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal)

            GeometryReader { geometry in
                let frame = fit(original.size, in: geometry.size)
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.88)
                    Image(uiImage: original)
                        .resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                    Rectangle()
                        .stroke(DokuTheme.orange, lineWidth: 3)
                        .frame(width: crop.width * frame.width, height: crop.height * frame.height)
                        .position(x: frame.minX + crop.midX * frame.width,
                                  y: frame.minY + crop.midY * frame.height)
                    ForEach(Corner.allCases, id: \.self) { corner in
                        handle(corner, imageFrame: frame)
                    }
                }
                .coordinateSpace(name: "cropArea")
            }
            .frame(height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 13))

            HStack {
                Button("Zurücksetzen") { crop = CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9) }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Beschneiden") { applyCrop() }
                    .buttonStyle(.borderedProminent)
                    .tint(DokuTheme.orange)
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding(.top, 18)
        .background(DokuTheme.background.ignoresSafeArea())
        .navigationTitle("Seite beschneiden")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } } }
    }

    @ViewBuilder
    private func handle(_ corner: Corner, imageFrame frame: CGRect) -> some View {
        let right = corner == .topRight || corner == .bottomRight
        let bottom = corner == .bottomLeft || corner == .bottomRight
        let x = frame.minX + (right ? crop.maxX : crop.minX) * frame.width
        let y = frame.minY + (bottom ? crop.maxY : crop.minY) * frame.height
        Circle()
            .fill(DokuTheme.turquoise)
            .frame(width: 27, height: 27)
            .overlay(Circle().stroke(.white, lineWidth: 3))
            .position(x: x, y: y)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("cropArea"))
                .onChanged { value in
                    let nx = min(1, max(0, (value.location.x - frame.minX) / frame.width))
                    let ny = min(1, max(0, (value.location.y - frame.minY) / frame.height))
                    var minX = crop.minX
                    var maxX = crop.maxX
                    var minY = crop.minY
                    var maxY = crop.maxY
                    if right { maxX = max(minX + 0.08, nx) } else { minX = min(maxX - 0.08, nx) }
                    if bottom { maxY = max(minY + 0.08, ny) } else { minY = min(maxY - 0.08, ny) }
                    crop = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                })
    }

    private func fit(_ image: CGSize, in bounds: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, bounds.width > 0, bounds.height > 0 else { return .zero }
        let scale = min(bounds.width / image.width, bounds.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func applyCrop() {
        guard let cg = original.pixelsUpright().cgImage else { return }
        let pixelBounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let pixelCrop = CGRect(x: crop.minX * pixelBounds.width,
                               y: crop.minY * pixelBounds.height,
                               width: crop.width * pixelBounds.width,
                               height: crop.height * pixelBounds.height)
            .integral.intersection(pixelBounds)
        guard let result = cg.cropping(to: pixelCrop) else { return }
        onSave(UIImage(cgImage: result))
        dismiss()
    }
}

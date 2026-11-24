import SwiftUI

/// Verbindliche Qualitätskontrolle VOR jedem Export.
/// Die Bilder sind die aktuellen Scanbilder nach Zuschneiden/Drehen/Schwärzen.
/// Ein „Original“ kann deshalb niemals eine vorgenommene Schwärzung aufheben.
struct ExportReviewView: View {
    let pages: [ScannedPage]
    let appearance: ScanAppearance
    let quality: PDFQuality
    let onCancel: () -> Void
    let onConfirm: (Set<UUID>) -> Void

    @State private var pageIndex = 0
    @State private var showingOriginal = false
    @State private var originalPageIDs = Set<UUID>()
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private var page: ScannedPage { pages[pageIndex] }
    private var previewKey: String {
        "\(page.id.uuidString)-\(appearance.rawValue)-\(quality.rawValue)-\(showingOriginal)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Seite \(pageIndex + 1) von \(pages.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Picker("Vorschau", selection: $showingOriginal) {
                    Text("Optimiert").tag(false)
                    Text("Original").tag(true)
                }
                .pickerStyle(.segmented)

                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        ZStack {
                            Color.white
                            if showingOriginal {
                                previewImage(page.image, size: geometry.size)
                            } else if let processedImage {
                                previewImage(processedImage, size: geometry.size)
                            } else {
                                ProgressView("Bild wird aufbereitet …")
                                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(minHeight: 230)

                HStack {
                    Button("Vorherige", systemImage: "chevron.left") {
                        pageIndex = max(0, pageIndex - 1)
                        zoom = 1
                        showingOriginal = originalPageIDs.contains(page.id)
                    }
                    .disabled(pageIndex == 0)
                    Spacer()
                    Button("Nächste", systemImage: "chevron.right") {
                        pageIndex = min(pages.count - 1, pageIndex + 1)
                        zoom = 1
                        showingOriginal = originalPageIDs.contains(page.id)
                    }
                    .disabled(pageIndex >= pages.count - 1)
                }
                .buttonStyle(.bordered)

                Toggle("Original für diese Seite verwenden", isOn: Binding(
                    get: { originalPageIDs.contains(page.id) },
                    set: { useOriginal in
                        if useOriginal { originalPageIDs.insert(page.id) }
                        else { originalPageIDs.remove(page.id) }
                        showingOriginal = useOriginal
                    }
                ))
                .font(.subheadline.weight(.medium))

                Text("Original bedeutet: Scanbild einschließlich bisheriger Zuschnitte und Schwärzungen. 2 Finger zum Vergrößern. Für jede Seite separat entscheiden.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(originalPageIDs.count) von \(pages.count) Seiten werden im Original ausgegeben.")
                    .font(.caption).foregroundStyle(.secondary)

                Button {
                    onConfirm(originalPageIDs)
                } label: {
                    Label("Auswahl übernehmen und PDF speichern/teilen", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryActionStyle())
                .disabled(!showingOriginal && (isProcessing || processedImage == nil))
            }
            .padding(16)
            .background(DokuTheme.background.ignoresSafeArea())
            .navigationTitle("Bildqualität prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { onCancel() } }
            }
            .task(id: previewKey) { await preparePreview() }
        }
    }

    private func previewImage(_ image: UIImage, size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size.width * min(6, max(1, zoom * pinch)))
            .frame(minHeight: size.height)
            .gesture(MagnificationGesture()
                .updating($pinch) { value, state, _ in state = value }
                .onEnded { value in zoom = min(6, max(1, zoom * value)) })
            .onTapGesture(count: 2) { zoom = zoom > 1 ? 1 : 2.5 }
    }

    private func preparePreview() async {
        guard !showingOriginal else { return }
        let id = page.id
        let source = page.image
        processedImage = nil
        isProcessing = true
        let output = await Task.detached(priority: .userInitiated) {
            PDFCreator.preparedImage(source, quality: quality, appearance: appearance, useOriginal: false)
        }.value
        guard !Task.isCancelled, page.id == id else { return }
        processedImage = output
        isProcessing = false
    }
}

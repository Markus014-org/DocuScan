import SwiftUI

/// Verbindliche Seiten- und Dateigrößenkontrolle VOR jedem Speichern/Versenden.
/// „Original“ ist das bereits zugeschnittene/gedrehte/geschwärzte Scanbild.
/// Größen sind echte Bytes aus PDFCreator.create; exakt diese PDF wird freigegeben.
struct ExportReviewView: View {
    let pages: [ScannedPage]
    let appearance: ScanAppearance
    let quality: PDFQuality
    let choiceMode: PDFExportChoice
    let onCancel: () -> Void
    let onConfirm: (Data) -> Void

    @State private var pageIndex = 0
    @State private var showingOriginal = false
    @State private var originalPageIDs = Set<UUID>()
    @State private var selectedQuality: PDFQuality
    @State private var processedImage: UIImage?
    @State private var isProcessing = false
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    @State private var actualSizes: [PDFQuality: Int] = [:]
    @State private var unprocessedSize: Int?
    @State private var selectedPDF: Data?
    @State private var preparedForKey: String?
    @State private var isMeasuring = false
    @State private var measurementError: String?

    init(pages: [ScannedPage], appearance: ScanAppearance, quality: PDFQuality,
         choiceMode: PDFExportChoice, onCancel: @escaping () -> Void,
         onConfirm: @escaping (Data) -> Void) {
        self.pages = pages
        self.appearance = appearance
        self.quality = quality
        self.choiceMode = choiceMode
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _selectedQuality = State(initialValue: quality)
    }

    private var page: ScannedPage { pages[pageIndex] }
    private var previewKey: String {
        "\(page.id.uuidString)-\(appearance.rawValue)-\(selectedQuality.rawValue)-\(showingOriginal)"
    }
    private var measurementKey: String {
        let originalIDKey = originalPageIDs.map(\.uuidString).sorted().joined(separator: ",")
        return "\(originalIDKey)|\(selectedQuality.rawValue)|\(appearance.rawValue)|\(choiceMode.rawValue)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 13) {
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
                    .frame(height: 270)

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

                    Text("Original bedeutet: Scanbild nach eventuellem Zuschneiden, Drehen und Schwärzen. Die PDF-Komprimierung wird separat angewendet. 2 Finger zum Vergrößern.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(originalPageIDs.count) von \(pages.count) Seiten werden ohne Bildverbesserung ausgegeben.")
                        .font(.caption).foregroundStyle(.secondary)

                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("PDF-Dateigröße und Qualität").font(.headline)
                        if choiceMode == .askEveryTime {
                            Picker("Qualität für diese PDF", selection: $selectedQuality) {
                                ForEach(PDFQuality.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            ForEach(PDFQuality.allCases) { option in
                                HStack {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(option == selectedQuality ? .semibold : .regular)
                                    Spacer()
                                    if let bytes = actualSizes[option] {
                                        Text(fileSize(bytes))
                                            .font(.subheadline.monospacedDigit())
                                    } else {
                                        Text("Wird berechnet …")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } else {
                            Text("Fest eingestellt: \(selectedQuality.rawValue)")
                                .font(.subheadline)
                            Text("Die Qualität wurde separat für diese Scanart in den Einstellungen festgelegt.")
                                .font(.caption).foregroundStyle(.secondary)
                        }

                        if let bytes = actualSizes[selectedQuality] {
                            HStack {
                                Text("Fertige PDF")
                                Spacer()
                                Text(fileSize(bytes)).bold().monospacedDigit()
                            }
                            if let before = unprocessedSize, before > 0 {
                                HStack {
                                    Text("Unbearbeitete PDF (Vergleich)")
                                    Spacer()
                                    Text(fileSize(before)).monospacedDigit()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                let reduction = Int((1 - Double(bytes) / Double(before)) * 100)
                                if reduction > 0 {
                                    Text("\(reduction) % kleiner als die unbearbeitete Vergleichs-PDF.")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                } else if reduction < 0 {
                                    Text("\(-reduction) % größer als die unbearbeitete Vergleichs-PDF.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let measurementError {
                            Label(measurementError, systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if isMeasuring {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Tatsächliche PDF-Größen werden berechnet …")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Text("Die Größen werden aus echten, durchsuchbaren PDFs berechnet, nicht geschätzt. Je nach Seite können Varianten ähnlich groß sein oder die optimierte Datei größer ausfallen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(DokuTheme.panel, in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        guard preparedForKey == measurementKey, let selectedPDF else { return }
                        onConfirm(selectedPDF)
                    } label: {
                        Label("Geprüfte PDF speichern oder versenden", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(preparedForKey != measurementKey || selectedPDF == nil ||
                              (!showingOriginal && (isProcessing || processedImage == nil)))
                }
                .padding(16)
            }
            .background(DokuTheme.background.ignoresSafeArea())
            .navigationTitle("Bildqualität & Dateigröße")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { onCancel() } }
            }
            .task(id: previewKey) { await preparePreview() }
            .task(id: measurementKey) { await measureActualPDFSizes() }
        }
    }

    private func fileSize(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
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
        let currentQuality = selectedQuality
        processedImage = nil
        isProcessing = true
        let output = await Task.detached(priority: .userInitiated) {
            PDFCreator.preparedImage(source, quality: currentQuality,
                                     appearance: appearance, useOriginal: false)
        }.value
        guard !Task.isCancelled, page.id == id else { return }
        processedImage = output
        isProcessing = false
    }

    private func measureActualPDFSizes() async {
        let snapshot = pages
        let choice = choiceMode
        let selected = selectedQuality
        let imageMode = appearance
        let originals = originalPageIDs
        let key = measurementKey
        // Die gewählte Variante zuerst erzeugen; die andere(n) nur für den Vergleich.
        let otherQualities = choice == .askEveryTime
            ? PDFQuality.allCases.filter { $0 != selected }
            : []
        selectedPDF = nil
        preparedForKey = nil
        actualSizes = [:]
        unprocessedSize = nil
        measurementError = nil
        isMeasuring = true

        do {
            try Task.checkCancellation()
            let chosenPDF = try await Task.detached(priority: .userInitiated) {
                try PDFCreator.create(pages: snapshot, quality: selected,
                                      appearance: imageMode, originalPageIDs: originals)
            }.value
            try Task.checkCancellation()
            actualSizes[selected] = chosenPDF.count
            selectedPDF = chosenPDF
            preparedForKey = key

            // Originalvergleich: alle aktuellen Scanbilder, ohne zusätzliche Bildoptimierung
            // und ohne JPEG-Neukomprimierung. Diese Vergleichs-PDF wird nicht gespeichert.
            let allOriginalIDs = Set(snapshot.map(\.id))
            let originalPDF = try await Task.detached(priority: .utility) {
                try PDFCreator.create(pages: snapshot, quality: .lossless,
                                      appearance: .original, originalPageIDs: allOriginalIDs)
            }.value
            try Task.checkCancellation()
            unprocessedSize = originalPDF.count

            // Nur Größen übernehmen, die gewählte fertige PDF bleibt die einzige
            // im Speicher behaltene PDF-Variante.
            for item in otherQualities {
                try Task.checkCancellation()
                let variant = try await Task.detached(priority: .utility) {
                    try PDFCreator.create(pages: snapshot, quality: item,
                                          appearance: imageMode, originalPageIDs: originals)
                }.value
                try Task.checkCancellation()
                actualSizes[item] = variant.count
            }
        } catch is CancellationError {
            return
        } catch {
            if !Task.isCancelled { measurementError = "PDF-Größe konnte nicht vollständig ermittelt werden: \(error.localizedDescription)" }
        }
        if !Task.isCancelled { isMeasuring = false }
    }
}

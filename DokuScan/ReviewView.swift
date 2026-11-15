import SwiftUI
import MessageUI
import VisionKit

private struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}
private struct MailFile: Identifiable {
    let id = UUID()
    let url: URL
    let recipient: String
}

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    let kind: ScanKind
    let receiptFolderID: UUID?
    @State private var pages: [ScannedPage]
    @State private var selectedIndex = 0
    @State private var filename = ""
    @FocusState private var editingFilename: Bool
    @State private var userRenamed = false
    @State private var receipt = ReceiptFields()
    @State private var nextNumber = 1
    @State private var lastSavedName: String?
    @State private var isRecognizing = false
    @State private var showCrop = false
    @State private var showScanner = false
    @State private var showFavoritePicker = false
    @State private var sharedFile: ShareFile?
    @State private var mailFile: MailFile?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    init(initialImages: [UIImage], kind: ScanKind, receiptFolderID: UUID?) {
        self.kind = kind
        self.receiptFolderID = receiptFolderID
        _pages = State(initialValue: initialImages.map { ScannedPage(image: $0.pixelsUpright()) })
    }

    var body: some View {
        ZStack {
            DokuTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(kind == .document ? "Dokument prüfen" : "Beleg prüfen")
                            .font(.title2.bold())
                        Spacer()
                        Text("Seite \(pages.isEmpty ? 0 : selectedIndex + 1) von \(pages.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if pages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Keine gescannte Seite vorhanden", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                            Text("Es wurde kein Bild an die Prüfansicht übergeben. Bitte scanne mindestens eine Seite, bevor du eine PDF speicherst oder versendest.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button { showScanner = true } label: {
                                Label("Seite jetzt scannen", systemImage: "doc.viewfinder")
                            }
                            .buttonStyle(PrimaryActionStyle())
                        }
                        .surface()
                    }
                    if !pages.isEmpty {
                        scanPreview
                            .frame(height: 380)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .bottomTrailing) {
                                Label("2 Finger: Zoom", systemImage: "plus.magnifyingglass")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                                    .background(.regularMaterial, in: Capsule())
                                    .padding(8)
                            }

                        HStack {
                            Menu {
                                Button("Beschneiden", systemImage: "crop.rotate") { showCrop = true }
                                Button("90° nach links drehen", systemImage: "rotate.left") { rotate(clockwise: false) }
                                Button("90° nach rechts drehen", systemImage: "rotate.right") { rotate(clockwise: true) }
                                Button("Seite löschen", systemImage: "trash", role: .destructive) { deletePage() }
                            } label: { Label("Bearbeiten", systemImage: "slider.horizontal.3") }
                            Spacer()
                            Button { showScanner = true } label: {
                                Label("Weitere Seiten", systemImage: "plus.viewfinder")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        ScrollView(.horizontal) {
                            HStack(spacing: 9) {
                                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                                    Button {
                                        selectedIndex = index
                                        zoom = 1
                                    } label: {
                                        VStack(spacing: 3) {
                                            Image(uiImage: page.image)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 69, height: 89)
                                                .background(.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                                .overlay(RoundedRectangle(cornerRadius: 7)
                                                    .stroke(index == selectedIndex ? DokuTheme.orange : .clear, lineWidth: 3))
                                            Text("\(index + 1)")
                                                .font(.caption2.monospacedDigit())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)

                        DisclosureGroup("Erkannter Text (OCR) prüfen") {
                            Text(pages[selectedIndex].recognizedText.isEmpty ? "Noch kein Text erkannt." : pages[selectedIndex].recognizedText)
                                .font(.caption)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 9)
                        }
                        .padding(12)
                        .background(DokuTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                    }

                    if isRecognizing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Texterkennung läuft auf dem iPhone …")
                                .font(.footnote)
                        }
                    }

                    if kind == .receipt { receiptForm }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dateiname").font(.headline)
                        TextField("Name des Dokuments", text: $filename)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                            .focused($editingFilename)
                            .onChange(of: filename) { _, _ in
                                if editingFilename { userRenamed = true }
                            }
                            .textFieldStyle(.roundedBorder)
                        Text(".pdf wird automatisch ergänzt")
                            .font(.caption).foregroundStyle(.secondary)
                        if kind == .receipt {
                            Text("Letzter gespeicherter Beleg: \(lastSavedName ?? "Noch keiner gefunden")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .surface()

                    Button(action: save) {
                        Label("Speichern oder versenden", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryActionStyle())
                    .disabled(pages.isEmpty || isRecognizing)
                    .opacity(pages.isEmpty || isRecognizing ? 0.45 : 1)

                    if kind == .document {
                        Button { showFavoritePicker = true } label: {
                            Label("Favorisiertes Speichern", systemImage: "star.fill")
                        }
                        .buttonStyle(PrimaryActionStyle(tint: DokuTheme.turquoise))
                        .disabled(pages.isEmpty || isRecognizing)
                        .opacity(pages.isEmpty || isRecognizing ? 0.45 : 1)
                    }

                    Text(kind == .document
                         ? "„Speichern“ öffnet die iOS-Teilen-Ansicht für Dateien, E-Mail und andere Apps."
                         : "„Speichern“ schreibt die PDF direkt in den zuvor gewählten Ordner.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(17)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Schließen") { dismiss() } }
        }
        .task {
            await loadFolderSnapshot()
            await recognizePages()
        }
        .sheet(isPresented: $showCrop) {
            if !pages.isEmpty {
                NavigationStack {
                    CropEditor(original: pages[selectedIndex].image) { cropped in
                        pages[selectedIndex].image = cropped
                        pages[selectedIndex].segments = []
                        Task { await recognizePages() }
                    }
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            CameraScanner(
                onScanned: { images in
                    showScanner = false
                    guard !images.isEmpty else {
                        errorMessage = "Keine Seite aufgenommen. Bitte erneut scannen."
                        return
                    }
                    let firstNewPage = pages.count
                    pages.append(contentsOf: images.map { ScannedPage(image: $0.pixelsUpright()) })
                    selectedIndex = firstNewPage
                    zoom = 1
                    Task { await recognizePages() }
                },
                onCancel: { showScanner = false },
                onFailure: { error in
                    showScanner = false
                    errorMessage = error
                }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showFavoritePicker) {
            NavigationStack {
                FavoriteSavePicker { destination in
                    showFavoritePicker = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { save(favorite: destination) }
                }
            }
        }
        .sheet(item: $sharedFile) { ShareSheet(fileURL: $0.url) }
        .sheet(item: $mailFile) { mail in
            MailComposer(fileURL: mail.url, recipient: mail.recipient) { mailFile = nil }
        }
        .alert("Hinweis", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("Gespeichert", isPresented: Binding(
            get: { successMessage != nil }, set: { if !$0 { successMessage = nil } }
        )) {
            Button("Fertig") { successMessage = nil; dismiss() }
        } message: { Text(successMessage ?? "") }
    }

    private var scanPreview: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: pages[selectedIndex].image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width * min(6, max(1, zoom * pinch)))
                    .frame(minHeight: geo.size.height)
                    .gesture(MagnificationGesture()
                        .updating($pinch) { value, state, _ in state = value }
                        .onEnded { value in zoom = min(6, max(1, zoom * value)) })
                    .onTapGesture(count: 2) { zoom = zoom > 1 ? 1 : 2.5 }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var receiptForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Belegdaten aus OCR").font(.headline)
            Text("Bitte Aussteller, teuerste Position, Datum, Gesamtbetrag und Steuer prüfen. OCR kann sich irren.")
                .font(.footnote).foregroundStyle(.secondary)
            if receipt.issuer.isEmpty || receipt.item.isEmpty {
                Text("Ein Feld konnte nicht zuverlässig erkannt werden. Bitte Aussteller und Artikel ergänzen.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Group {
                TextField("Ausstellende Firma", text: $receipt.issuer)
                TextField("Teuerste Position", text: $receipt.item)
                DatePicker("Belegdatum", selection: $receipt.date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "de_DE"))
                TextField("Gesamtbetrag", text: $receipt.total)
                    .keyboardType(.decimalPad)
                HStack {
                    Text("Mehrwertsteuer")
                    Spacer()
                    Picker("Mehrwertsteuer", selection: $receipt.vat) {
                        ForEach(["19%", "7%", "0%", "gemischt", "unbekannt"], id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            Button("Dateinamen aus diesen Feldern übernehmen") {
                userRenamed = false
                filename = FileNaming.receiptName(number: nextNumber, fields: receipt)
            }
            .font(.subheadline.weight(.semibold))
        }
        .surface()
    }

    private func loadFolderSnapshot() async {
        guard kind == .receipt, let id = receiptFolderID,
              let folder = model.folders.first(where: { $0.id == id }) else { return }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try StorageService.snapshot(for: folder)
            }.value
            nextNumber = result.nextNumber
            lastSavedName = result.lastName
            if !userRenamed { filename = FileNaming.receiptName(number: nextNumber, fields: receipt) }
        } catch { errorMessage = "Ordner konnte nicht gelesen werden: \(error.localizedDescription)" }
    }

    private func recognizePages() async {
        let ids = pages.map(\.id)
        let images = pages.map(\.image)
        isRecognizing = true
        defer { isRecognizing = false }
        do {
            let recognized = try await OCRService.recognize(images)
            // Alte OCR-Läufe nicht auf zwischenzeitlich veränderte Seiten anwenden.
            guard pages.map(\.id) == ids, pages.count == recognized.count else { return }
            for i in pages.indices { pages[i].segments = recognized[i] }
            let text = pages.map(\.recognizedText).joined(separator: "\n")
            if kind == .document {
                if !userRenamed { filename = FileNaming.documentName(from: text) }
            } else {
                receipt = ReceiptNamer.parse(segmentsByPage: pages.map(\.segments))
                if !userRenamed { filename = FileNaming.receiptName(number: nextNumber, fields: receipt) }
            }
        } catch { errorMessage = "OCR konnte nicht abgeschlossen werden: \(error.localizedDescription)" }
    }

    private func rotate(clockwise: Bool) {
        guard !pages.isEmpty else { return }
        let image = pages[selectedIndex].image.pixelsUpright()
        let newSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rotated = UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2,
                                  width: image.size.width, height: image.size.height))
        }
        pages[selectedIndex].image = rotated
        pages[selectedIndex].segments = []
        zoom = 1
        Task { await recognizePages() }
    }

    private func deletePage() {
        guard !pages.isEmpty else { return }
        pages.remove(at: selectedIndex)
        selectedIndex = max(0, min(selectedIndex, pages.count - 1))
        zoom = 1
        if !pages.isEmpty { Task { await recognizePages() } }
    }

    private func save() {
        guard !pages.isEmpty else {
            errorMessage = "Keine Seiten vorhanden. Bitte zuerst eine Seite scannen."
            return
        }
        if kind == .document {
            save(favorite: FavoriteDestination(kind: .share, label: "Teilen"))
        } else {
            guard let id = receiptFolderID,
                  let folder = model.folders.first(where: { $0.id == id }) else {
                errorMessage = "Bitte zuerst einen Speicherort für Belege wählen."
                return
            }
            do {
                let outputFilename = try FileNaming.filename(self.filename)
                let data = try PDFCreator.create(pages: pages)
                let savedURL = try StorageService.save(data, filename: outputFilename, in: folder)
                successMessage = "\(savedURL.lastPathComponent)\n\nSpeicherort: \(folder.name)"
            } catch { errorMessage = error.localizedDescription }
        }
    }

    private func save(favorite: FavoriteDestination) {
        guard !pages.isEmpty else {
            errorMessage = "Keine Seiten vorhanden. Bitte zuerst eine Seite scannen."
            return
        }
        do {
            let name = try FileNaming.filename(filename)
            let data = try PDFCreator.create(pages: pages)
            switch favorite.kind {
            case .folder:
                guard let id = favorite.folderID,
                      let folder = model.folders.first(where: { $0.id == id }) else {
                    throw UserFacingError(message: "Der favorisierte Ordner ist nicht mehr vorhanden.")
                }
                let savedURL = try StorageService.save(data, filename: name, in: folder)
                successMessage = "\(savedURL.lastPathComponent)\n\nSpeicherort: \(folder.name)"
            case .share:
                sharedFile = ShareFile(url: try StorageService.temporaryPDF(data: data, filename: name))
            case .email:
                let url = try StorageService.temporaryPDF(data: data, filename: name)
                if MFMailComposeViewController.canSendMail(), let email = favorite.email {
                    mailFile = MailFile(url: url, recipient: email)
                } else {
                    sharedFile = ShareFile(url: url)
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct FavoriteSavePicker: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onSelect: (FavoriteDestination) -> Void

    var body: some View {
        List {
            if model.favorites.isEmpty {
                ContentUnavailableView("Noch keine Favoriten", systemImage: "star", description: Text("Lege zuerst einen Favoriten an."))
            }
            ForEach(model.favorites) { destination in
                Button {
                    onSelect(destination)
                } label: {
                    Label(destination.label, systemImage: symbol(for: destination.kind))
                }
            }
            NavigationLink("Favoriten bearbeiten") { FavoritesView() }
        }
        .navigationTitle("Favorisiertes Speichern")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Schließen") { dismiss() } } }
    }
}

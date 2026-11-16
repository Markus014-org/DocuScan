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
    let ruleMode: Bool
    let presetCategory: String
    let filenameTemplate: String
    @State private var targetFolderID: UUID?
    @State private var detectedMerchant = ""
    @State private var category = ""
    @State private var tagsInput = ""
    @State private var returnEnabled = false
    @State private var warrantyEnabled = false
    @State private var returnDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var warrantyDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    @State private var qualityIssues: [String] = []
    @State private var showOCRCorrection = false
    @State private var showRedaction = false
    @State private var duplicateWarning = false
    @State private var pendingDestination: FavoriteDestination?
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

    init(initialImages: [UIImage], kind: ScanKind, receiptFolderID: UUID?, ruleMode: Bool = false, presetCategory: String = "", filenameTemplate: String = "") {
        self.kind = kind
        self.receiptFolderID = receiptFolderID
        self.ruleMode = ruleMode
        self.presetCategory = presetCategory
        self.filenameTemplate = filenameTemplate
        _targetFolderID = State(initialValue: receiptFolderID)
        _category = State(initialValue: presetCategory)
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
                                Button("OCR-Text korrigieren", systemImage: "text.badge.checkmark") { showOCRCorrection = true }
                                if model.preferences.redactionEnabled {
                                    Button("Vertrauliche Stellen schwärzen", systemImage: "rectangle.fill") { showRedaction = true }
                                }
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

                        if !qualityIssues.isEmpty {
                            DisclosureGroup("Scanqualität prüfen (\(qualityIssues.count) Hinweise)") {
                                ForEach(qualityIssues, id: \.self) { issue in
                                    Label(issue, systemImage: "exclamationmark.triangle")
                                        .font(.caption).foregroundStyle(.orange)
                                }
                            }
                            .padding(12)
                            .background(DokuTheme.panel, in: RoundedRectangle(cornerRadius: 13))
                        }

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
                    if kind == .document && model.preferences.tagsEnabled {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Organisation (optional)").font(.headline)
                            TextField("Kategorie", text: $category)
                            TextField("Schlagwörter, mit Komma trennen", text: $tagsInput)
                        }
                        .textFieldStyle(.roundedBorder)
                        .surface()
                    }

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
            updateQuality()
            await recognizePages()
        }
        .task(id: targetFolderID) { await loadFolderSnapshot() }
        .sheet(isPresented: $showCrop) {
            if !pages.isEmpty {
                NavigationStack {
                    CropEditor(original: pages[selectedIndex].image) { cropped in
                        pages[selectedIndex].image = cropped
                        pages[selectedIndex].segments = []
                        pages[selectedIndex].ocrManuallyCorrected = false
                        updateQuality()
                        Task { await recognizePages() }
                    }
                }
            }
        }
        .sheet(isPresented: $showOCRCorrection) {
            if !pages.isEmpty {
                NavigationStack {
                    OCRCorrectionView(text: pages[selectedIndex].recognizedText) { corrected in
                        applyOCRCorrection(corrected)
                    }
                }
            }
        }
        .sheet(isPresented: $showRedaction) {
            if !pages.isEmpty && model.preferences.redactionEnabled {
                NavigationStack {
                    RedactionView(original: pages[selectedIndex].image) { redacted in
                        pages[selectedIndex].image = redacted
                        pages[selectedIndex].segments = []
                        pages[selectedIndex].ocrManuallyCorrected = false
                        updateQuality()
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
                    updateQuality()
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
        .confirmationDialog("Möglicherweise bereits archiviert", isPresented: $duplicateWarning, titleVisibility: .visible) {
            Button("Trotzdem speichern") { performSave(favorite: pendingDestination) }
            Button("Abbrechen", role: .cancel) { pendingDestination = nil }
        } message: {
            Text("Ein Beleg mit demselben Händler, Datum und Gesamtbetrag ist bereits im Archiv vorhanden.")
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
            if ruleMode && model.preferences.routingEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Automatische Ablage", systemImage: "arrow.triangle.branch").font(.subheadline.bold())
                    Picker("Zielordner", selection: $targetFolderID) {
                        Text("Bitte Ordner auswählen").tag(nil as UUID?)
                        ForEach(model.folders) { folder in Text(folder.name).tag(folder.id as UUID?) }
                    }
                    if let folder = model.folders.first(where: { $0.id == targetFolderID }) {
                        Text("Speichert direkt in: " + folder.name).font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Keine passende Regel: bitte einen Speicherort wählen.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            if model.preferences.tagsEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Kategorie (optional)", text: $category)
                    TextField("Schlagwörter, mit Komma trennen", text: $tagsInput)
                }
            }
            if model.preferences.remindersEnabled {
                Toggle("An Rückgabefrist erinnern", isOn: $returnEnabled)
                if returnEnabled { DatePicker("Rückgabe bis", selection: $returnDate, in: Date()..., displayedComponents: .date) }
                Toggle("An Garantieende erinnern", isOn: $warrantyEnabled)
                if warrantyEnabled { DatePicker("Garantie bis", selection: $warrantyDate, in: Date()..., displayedComponents: .date) }
            }
            Button("Dateinamen aus diesen Feldern übernehmen") {
                userRenamed = false
                filename = FileNaming.receiptName(number: nextNumber, fields: receipt)
            }
            .font(.subheadline.weight(.semibold))
        }
        .surface()
    }

    private func loadFolderSnapshot() async {
        guard kind == .receipt, let id = targetFolderID,
              let folder = model.folders.first(where: { $0.id == id }) else { return }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try StorageService.snapshot(for: folder)
            }.value
            nextNumber = result.nextNumber
            lastSavedName = result.lastName
            if !userRenamed { filename = proposedName(text: pages.map(\.recognizedText).joined(separator: "\n")) }
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
            for i in pages.indices {
                if !pages[i].ocrManuallyCorrected { pages[i].segments = recognized[i] }
            }
            let text = pages.map(\.recognizedText).joined(separator: "\n")
            if kind == .document {
                if !userRenamed { filename = proposedName(text: text) }
            } else {
                let detected = ReceiptNamer.parse(segmentsByPage: pages.map(\.segments))
                detectedMerchant = detected.issuer
                receipt = detected
                receipt.issuer = model.canonicalMerchant(for: detected.issuer)
                if ruleMode && model.preferences.routingEnabled {
                    let rule = model.matchingRule(merchant: receipt.issuer, text: text)
                    targetFolderID = rule?.folderID
                    if model.preferences.tagsEnabled, let rule, !rule.category.isEmpty { category = rule.category }
                }
                if !userRenamed { filename = proposedName(text: text) }
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
        pages[selectedIndex].ocrManuallyCorrected = false
        updateQuality()
        zoom = 1
        Task { await recognizePages() }
    }

    private func deletePage() {
        guard !pages.isEmpty else { return }
        pages.remove(at: selectedIndex)
        selectedIndex = max(0, min(selectedIndex, pages.count - 1))
        zoom = 1
        updateQuality()
        if !pages.isEmpty { Task { await recognizePages() } }
    }

    private func proposedName(text: String) -> String {
        let base = kind == .receipt
            ? FileNaming.receiptName(number: nextNumber, fields: receipt)
            : FileNaming.documentName(from: text)
        guard !filenameTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        var output = filenameTemplate
        let values: [String: String] = [
            "{datum}": FileNaming.format(kind == .receipt ? receipt.date : Date(), pattern: "yyMMdd"),
            "{titel}": FileNaming.cleanComponent(text.components(separatedBy: .newlines).first ?? "Dokument"),
            "{firma}": FileNaming.cleanComponent(receipt.issuer),
            "{artikel}": FileNaming.cleanComponent(receipt.item),
            "{betrag}": receipt.total,
            "{nr}": String(format: "%03d", nextNumber)
        ]
        for (token, value) in values { output = output.replacingOccurrences(of: token, with: value) }
        return FileNaming.cleanComponent(output).replacingOccurrences(of: " ", with: "_")
    }

    private func updateQuality() {
        qualityIssues = pages.enumerated().flatMap { index, page in
            ImageQuality.warnings(for: page.image).map { "Seite \(index + 1): " + $0 }
        }
    }

    private func applyOCRCorrection(_ corrected: String) {
        guard !pages.isEmpty else { return }
        let original = pages[selectedIndex].segments
        let lines = corrected.components(separatedBy: .newlines)
        var updated: [OCRSegment] = []
        for (index, line) in lines.enumerated() where !line.isEmpty {
            // Positionsangaben möglichst beibehalten. Neue Zeilen erhalten eine approximative Position.
            let box = original.indices.contains(index)
                ? original[index].boundingBox
                : CGRect(x: 0.06, y: max(0.02, 0.92 - CGFloat(index) * 0.04), width: 0.88, height: 0.025)
            updated.append(OCRSegment(text: line, boundingBox: box))
        }
        pages[selectedIndex].segments = updated
        pages[selectedIndex].ocrManuallyCorrected = true
        if kind == .receipt {
            let parsed = ReceiptNamer.parse(segmentsByPage: pages.map(\.segments))
            detectedMerchant = parsed.issuer
            receipt = parsed
            receipt.issuer = model.canonicalMerchant(for: parsed.issuer)
            if ruleMode && model.preferences.routingEnabled {
                let text = pages.map(\.recognizedText).joined(separator: "\n")
                let rule = model.matchingRule(merchant: receipt.issuer, text: text)
                targetFolderID = rule?.folderID
                if model.preferences.tagsEnabled, let rule { category = rule.category }
            }
        }
        if !userRenamed {
            filename = proposedName(text: pages.map(\.recognizedText).joined(separator: "\n"))
        }
    }

    private func save() { attemptSave(favorite: nil) }

    private func save(favorite: FavoriteDestination) { attemptSave(favorite: favorite) }

    private func attemptSave(favorite: FavoriteDestination?) {
        guard !pages.isEmpty && !isRecognizing else {
            errorMessage = "Bitte zuerst mindestens eine Seite scannen und die Texterkennung abschließen."
            return
        }
        let fingerprint = ArchiveStore.fingerprint(kind: kind, ocr: pages.map(\.recognizedText).joined(separator: "\n"), receipt: receipt)
        if !fingerprint.isEmpty && model.records.contains(where: { $0.fingerprint == fingerprint }) {
            pendingDestination = favorite
            duplicateWarning = true
            return
        }
        performSave(favorite: favorite)
    }

    private func performSave(favorite: FavoriteDestination?) {
        guard !pages.isEmpty else { return }
        do {
            let name = try FileNaming.filename(filename)
            let pdf = try PDFCreator.create(pages: pages, quality: model.preferences.pdfQuality)
            let target: FavoriteDestination? = favorite
            var location = "Lokales Archiv / Teilen"
            var savedURL: URL?
            if kind == .receipt && target == nil {
                guard let id = targetFolderID, let folder = model.folders.first(where: { $0.id == id }) else {
                    throw UserFacingError(message: "Bitte zuerst einen Zielordner für den Beleg auswählen.")
                }
                savedURL = try StorageService.save(pdf, filename: name, in: folder)
                location = folder.name
            } else if let favorite = target, favorite.kind == .folder {
                guard let id = favorite.folderID, let folder = model.folders.first(where: { $0.id == id }) else {
                    throw UserFacingError(message: "Dieser favorisierte Ordner wurde nicht gefunden.")
                }
                savedURL = try StorageService.save(pdf, filename: name, in: folder)
                location = folder.name
            }
            var record = SavedRecord(filename: savedURL?.lastPathComponent ?? name,
                                     storedFile: UUID().uuidString + ".pdf", kind: kind.rawValue)
            record.documentDate = kind == .receipt ? receipt.date : Date()
            record.issuer = kind == .receipt ? receipt.issuer : ""
            record.item = kind == .receipt ? receipt.item : ""
            record.total = kind == .receipt ? receipt.total : ""
            record.vat = kind == .receipt ? receipt.vat : ""
            record.ocrText = pages.map(\.recognizedText).joined(separator: "\n")
            record.fingerprint = ArchiveStore.fingerprint(kind: kind, ocr: record.ocrText, receipt: receipt)
            record.destination = location
            if model.preferences.tagsEnabled {
                record.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
                record.tags = tagsInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if model.preferences.remindersEnabled && kind == .receipt {
                record.returnDeadline = returnEnabled ? returnDate : nil
                record.warrantyEnd = warrantyEnabled ? warrantyDate : nil
            }
            try model.archive(pdf: pdf, record: record)
            if kind == .receipt {
                model.rememberMerchant(detected: detectedMerchant, corrected: receipt.issuer)
            }
            if model.preferences.remindersEnabled { Task { await ReminderService.schedule(for: record) } }
            if let url = savedURL {
                successMessage = url.lastPathComponent + "\n\nSpeicherort: " + location + "\nArchivkopie erstellt."
            } else if target?.kind == .email, let address = target?.email,
                      MFMailComposeViewController.canSendMail() {
                let temp = try StorageService.temporaryPDF(data: pdf, filename: name)
                mailFile = MailFile(url: temp, recipient: address)
            } else {
                sharedFile = ShareFile(url: try StorageService.temporaryPDF(data: pdf, filename: name))
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

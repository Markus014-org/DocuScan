import SwiftUI
import PDFKit
import Charts

private struct MerchantTotal: Identifiable {
    let name: String
    let sum: Double
    var id: String { name }
}

private struct MonthlyTotal: Identifiable {
    let month: String
    let sum: Double
    var id: String { month }
}

struct ArchiveView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""
    @State private var showReceiptsOnly = false
    @State private var selectedCategory = "Alle"
    @State private var preview: ArchivePreview?
    @State private var shared: ArchiveShared?
    @State private var error: String?

    private var visible: [SavedRecord] {
        model.records.filter { record in
            (!showReceiptsOnly || record.kind == ScanKind.receipt.rawValue) &&
            (!model.preferences.tagsEnabled || selectedCategory == "Alle" || record.category == selectedCategory) &&
            (search.isEmpty || ([record.filename, record.issuer, record.item, record.ocrText] +
                (model.preferences.tagsEnabled ? [record.category, record.tags.joined(separator: " ")] : []))
                .contains { $0.localizedCaseInsensitiveContains(search) })
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private var categories: [String] {
        ["Alle"] + Array(Set(model.records.map(\.category).filter { !$0.isEmpty })).sorted()
    }

    private var receiptTotals: [MonthlyTotal] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        var totals: [String: Double] = [:]
        for record in model.records where record.kind == ScanKind.receipt.rawValue {
            let amount = record.total.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            if let number = Double(amount), number > 0 {
                totals[formatter.string(from: record.documentDate), default: 0] += number
            }
        }
        return totals.map { MonthlyTotal(month: $0.key, sum: $0.value) }.sorted { $0.month < $1.month }
    }

    private var merchantTotals: [MerchantTotal] {
        var sums: [String: Double] = [:]
        for record in model.records where record.kind == ScanKind.receipt.rawValue {
            let raw = record.total.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            guard let sum = Double(raw), sum > 0 else { continue }
            let merchant = record.issuer.isEmpty ? "Unbekannt" : record.issuer
            sums[merchant, default: 0] += sum
        }
        return sums.map { MerchantTotal(name: $0.key, sum: $0.value) }
            .sorted { $0.sum > $1.sum }.prefix(8).map { $0 }
    }

    private var estimatedVAT: Double {
        model.records.reduce(0) { sum, receipt in
            guard receipt.kind == ScanKind.receipt.rawValue,
                  ["7%", "19%"].contains(receipt.vat) else { return sum }
            let raw = receipt.total.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            guard let gross = Double(raw), gross > 0 else { return sum }
            let rate = receipt.vat == "7%" ? 0.07 : 0.19
            return sum + gross * rate / (1 + rate)
        }
    }

    var body: some View {
        List {
            if !receiptTotals.isEmpty {
                Section("Ausgaben pro Monat (EUR)") {
                    Chart(receiptTotals) { value in
                        BarMark(x: .value("Monat", value.month), y: .value("Euro", value.sum))
                    }
                    .frame(height: 160)
                    DisclosureGroup("Ausgaben nach Händlern") {
                        ForEach(merchantTotals) { item in
                            HStack {
                                Text(item.name).lineLimit(1)
                                Spacer()
                                Text(item.sum, format: .currency(code: "EUR"))
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                        }
                    }
                    Text("Geschätzte USt aus Belegen mit eindeutig 7 % oder 19 %: " +
                         estimatedVAT.formatted(.currency(code: "EUR")))
                        .font(.footnote)
                    Text("Gemischte Steuersätze und OCR-Fehler bleiben in der USt-Schätzung unberücksichtigt.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Belegdaten als CSV exportieren", systemImage: "square.and.arrow.up") {
                        do { shared = ArchiveShared(url: try ArchiveStore.csvFile(records: model.records, includeTags: model.preferences.tagsEnabled)) }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            if model.records.contains(where: { $0.kind == ScanKind.receipt.rawValue }) && receiptTotals.isEmpty {
                Section {
                    Button("Belegdaten als CSV exportieren", systemImage: "square.and.arrow.up") {
                        do { shared = ArchiveShared(url: try ArchiveStore.csvFile(records: model.records, includeTags: model.preferences.tagsEnabled)) }
                        catch { self.error = error.localizedDescription }
                    }
                }
            }
            Section {
                Toggle("Nur Belege", isOn: $showReceiptsOnly)
                if model.preferences.tagsEnabled {
                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { item in Text(item).tag(item) }
                    }
                }
            }
            Section("Archiv – \(visible.count) Dokumente") {
                if visible.isEmpty {
                    ContentUnavailableView("Keine Treffer", systemImage: "doc.text.magnifyingglass", description: Text("Scanne ein Dokument oder suche nach einem anderen Begriff."))
                }
                ForEach(visible) { record in
                    Button {
                        let url = ArchiveStore.url(for: record)
                        if FileManager.default.fileExists(atPath: url.path) { preview = ArchivePreview(record: record) }
                        else { error = "Die lokale Archivkopie wurde nicht gefunden." }
                    } label: {
                        HStack {
                            Image(systemName: record.kind == "receipt" ? "receipt" : "doc.text")
                                .foregroundStyle(DokuTheme.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.filename).font(.subheadline.weight(.medium)).lineLimit(2)
                                HStack {
                                    Text(record.createdAt, style: .date)
                                    if !record.total.isEmpty && record.kind == "receipt" { Text("· " + record.total + " €") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                                if !record.category.isEmpty && model.preferences.tagsEnabled {
                                    Text(record.category).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            ReminderService.cancel(for: record)
                            model.deleteRecord(record)
                        } label: { Label("Aus Archiv entfernen", systemImage: "trash") }
                    }
                }
            }
        }
        .searchable(text: $search, prompt: "In PDFs und Metadaten suchen")
        .navigationTitle("Archiv & Ausgaben")
        .sheet(item: $preview) { item in ArchiveDocumentView(record: item.record) }
        .sheet(item: $shared) { ShareSheet(fileURL: $0.url) }
        .alert("Hinweis", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }
}

private struct ArchivePreview: Identifiable {
    let id = UUID()
    let record: SavedRecord
}
private struct ArchiveShared: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ArchiveDocumentView: View {
    let record: SavedRecord
    @Environment(\.dismiss) private var dismiss
    @State private var sharing: ArchiveShared?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            PDFPreview(url: ArchiveStore.url(for: record))
                .navigationTitle(record.filename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Fertig") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Teilen", systemImage: "square.and.arrow.up") {
                            do {
                                let pdf = try Data(contentsOf: ArchiveStore.url(for: record))
                                sharing = ArchiveShared(url: try StorageService.temporaryPDF(data: pdf, filename: record.filename))
                            } catch { error = error.localizedDescription }
                        }
                    }
                }
                .sheet(item: $sharing) { ShareSheet(fileURL: $0.url) }
                .alert("Archivdatei konnte nicht geteilt werden", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("OK", role: .cancel) {}
                } message: { Text(error ?? "") }
        }
    }
}

private struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.document = PDFDocument(url: url)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) { }
}

import Foundation
import CryptoKit

// Eigenständige lokale Archivkopie: externe Datei-Anbieter bleiben unberührt.
enum ArchiveStore {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Scanchris-Archiv", isDirectory: true)
    }

    static func save(pdf: Data, filename: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(filename)
        try pdf.write(to: url, options: .atomic)
        return url
    }

    static func url(for record: SavedRecord) -> URL { directory.appendingPathComponent(record.storedFile) }

    static func delete(filename: String) throws {
        let url = directory.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    static func fingerprint(kind: ScanKind, ocr: String, receipt: ReceiptFields) -> String {
        let basis: String
        if kind == .receipt {
            let merchant = receipt.issuer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let amount = receipt.total.trimmingCharacters(in: .whitespacesAndNewlines)
            guard merchant.count >= 3 && amount != "0,00" else { return "" }
            basis = merchant + "|" + amount + "|" + FileNaming.format(receipt.date, pattern: "yyyy-MM-dd")
        } else {
            let text = ocr.lowercased().filter { !$0.isWhitespace }
            guard text.count > 60 else { return "" }
            basis = text
        }
        let digest = SHA256.hash(data: Data(basis.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func csv(_ records: [SavedRecord], includeTags: Bool) -> Data {
        func q(_ str: String) -> String { "\"" + str.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var lines = ["Datei;Datum;Händler;Position;Betrag;USt;Kategorie;Schlagwörter;Ablage"]
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "de_DE")
        for record in records where record.kind == ScanKind.receipt.rawValue {
            lines.append([record.filename, formatter.string(from: record.documentDate), record.issuer, record.item, record.total, record.vat, includeTags ? record.category : "", includeTags ? record.tags.joined(separator: ", ") : "", record.destination].map(q).joined(separator: ";"))
        }
        return Data(("\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n").utf8)
    }

    static func csvFile(records: [SavedRecord], includeTags: Bool) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Scanchris-Ausgaben.csv")
        try csv(records, includeTags: includeTags).write(to: url, options: .atomic)
        return url
    }
}

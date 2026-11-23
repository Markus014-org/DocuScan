import Foundation

/// Alle Dateizugriffe erfolgen mit Security Scope und NSFileCoordinator.
enum StorageService {
    static func resolve(_ folder: SavedFolder) throws -> URL {
        var stale = false
        let url = try URL(resolvingBookmarkData: folder.bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale {
            throw UserFacingError(message: "Der Ordnerzugriff ist abgelaufen. Bitte den Speicherort in Einstellungen löschen und erneut hinzufügen.")
        }
        return url
    }

    /// Erfasst Dateien im tatsächlichen Zielordner, auch wenn sie außerhalb
    /// von Scanchris hinzugefügt wurden. Unterordner zählen nicht mit.
    private static func fileNames(in directory: URL) throws -> [String] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        )
        return urls.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
        }.map(\.lastPathComponent)
    }

    private static func nextReceiptNumber(in filenames: [String]) throws -> Int {
        let maximum = filenames.compactMap(FileNaming.receiptSequenceNumber(from:)).max() ?? 0
        guard maximum < 999 else {
            throw UserFacingError(message: "Die höchste Nummer im Zielordner ist 999. Bitte einen neuen Zielordner wählen, damit die dreistellige Nummerierung erhalten bleibt.")
        }
        return maximum + 1
    }

    static func snapshot(for folder: SavedFolder) throws -> FolderSnapshot {
        let url = try resolve(folder)
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var readError: Error?
        var result: FolderSnapshot?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            do {
                let filenames = try fileNames(in: coordinated)
                let numbered = filenames.compactMap { name -> (Int, String)? in
                    guard let value = FileNaming.receiptSequenceNumber(from: name) else { return nil }
                    return (value, name)
                }
                let last = numbered.max { $0.0 < $1.0 }
                result = FolderSnapshot(nextNumber: try nextReceiptNumber(in: filenames), lastName: last?.1)
            } catch { readError = error }
        }
        if let error = coordinationError { throw error }
        if let error = readError { throw error }
        guard let result else { throw UserFacingError(message: "Der Zielordner konnte nicht gelesen werden.") }
        return result
    }

    @discardableResult
    static func save(_ fileData: Data, filename: String, in folder: SavedFolder,
                     numberReceipt: Bool = false) throws -> URL {
        let folderURL = try resolve(folder)
        let granted = folderURL.startAccessingSecurityScopedResource()
        defer { if granted { folderURL.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var savingError: Error?
        var writtenURL: URL?
        // Beim Speichern INNERHALB der koordinierten Operation erneut nachsehen.
        // Damit werden auch neue externe Dateien seit Öffnen der Prüfansicht erfasst.
        NSFileCoordinator().coordinate(writingItemAt: folderURL, options: .forMerging, error: &coordinationError) { coordinatedFolder in
            do {
                let manager = FileManager.default
                let base = (filename as NSString).deletingPathExtension
                var number = numberReceipt ? try nextReceiptNumber(in: fileNames(in: coordinatedFolder)) : 0
                var suffix = 1
                while true {
                    let proposed: String
                    if numberReceipt {
                        guard number <= 999 else {
                            throw UserFacingError(message: "Keine freie dreistellige Belegnummer mehr vorhanden. Bitte einen neuen Zielordner wählen.")
                        }
                        proposed = FileNaming.renumberReceiptFilename(filename, number: number)
                    } else {
                        proposed = suffix == 1 ? filename : "\(base)_\(suffix).pdf"
                    }
                    let candidate = coordinatedFolder.appendingPathComponent(proposed, isDirectory: false)
                    if manager.fileExists(atPath: candidate.path) {
                        if numberReceipt { number += 1 } else { suffix += 1 }
                        continue
                    }
                    do {
                        // .withoutOverwriting schützt Belege vor einem Dateikonflikt
                        // zwischen Prüfung und Schreibvorgang. Diese Option darf
                        // nicht mit .atomic kombiniert werden. Dokumente behalten
                        // die bisherige atomare Schreibweise.
                        try fileData.write(to: candidate,
                                           options: numberReceipt ? [.withoutOverwriting] : [.atomic])
                        writtenURL = folderURL.appendingPathComponent(candidate.lastPathComponent)
                        break
                    } catch let error as NSError where error.domain == NSCocoaErrorDomain &&
                                                     error.code == NSFileWriteFileExistsError {
                        if numberReceipt { number += 1 } else { suffix += 1 }
                    }
                }
            } catch { savingError = error }
        }
        if let error = coordinationError { throw error }
        if let error = savingError { throw error }
        guard let writtenURL else { throw UserFacingError(message: "Die Datei konnte nicht angelegt werden.") }
        return writtenURL
    }

    static func temporaryPDF(data: Data, filename: String) throws -> URL {
        // Jede Freigabe verwendet einen eigenen temporären Unterordner.
        // So bleibt der sichtbare PDF-Dateiname exakt wie vom Benutzer gewählt,
        // ohne dass parallele Freigaben oder alte Dateien kollidieren.
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Scanchris-Freigabe", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: .atomic)
        return url
    }
}

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

    static func snapshot(for folder: SavedFolder) throws -> FolderSnapshot {
        let url = try resolve(folder)
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var readError: Error?
        var names: [String] = []
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinated in
            do {
                let files = try FileManager.default.contentsOfDirectory(at: coordinated, includingPropertiesForKeys: nil)
                names = files.filter { $0.pathExtension.lowercased() == "pdf" }.map(\.lastPathComponent)
            } catch { readError = error }
        }
        if let error = coordinationError { throw error }
        if let error = readError { throw error }
        let numbered: [(number: Int, filename: String)] = names.compactMap { name in
            let prefix = name.prefix(while: { $0.isASCII && $0.isNumber })
            guard prefix.count >= 3,
                  name.dropFirst(prefix.count).first == "_", let number = Int(prefix) else { return nil }
            return (number, name)
        }
        let previous = numbered.max(by: { $0.number < $1.number })
        return FolderSnapshot(nextNumber: (previous?.number ?? 0) + 1, lastName: previous?.filename)
    }

    @discardableResult
    static func save(_ fileData: Data, filename: String, in folder: SavedFolder) throws -> URL {
        let folderURL = try resolve(folder)
        let granted = folderURL.startAccessingSecurityScopedResource()
        defer { if granted { folderURL.stopAccessingSecurityScopedResource() } }

        var coordinationError: NSError?
        var savingError: Error?
        var writtenURL: URL?
        // In den koordinierten Ordner schreiben (iCloud/Dropbox-Dateianbieter).
        NSFileCoordinator().coordinate(writingItemAt: folderURL, options: .forMerging, error: &coordinationError) { coordinatedFolder in
            do {
                var candidate = coordinatedFolder.appendingPathComponent(filename, isDirectory: false)
                let original = candidate.deletingPathExtension().lastPathComponent
                var suffix = 2
                while FileManager.default.fileExists(atPath: candidate.path) {
                    candidate = coordinatedFolder.appendingPathComponent("\(original)_\(suffix).pdf")
                    suffix += 1
                }
                try fileData.write(to: candidate, options: .atomic)
                writtenURL = folderURL.appendingPathComponent(candidate.lastPathComponent)
            } catch { savingError = error }
        }
        if let error = coordinationError { throw error }
        if let error = savingError { throw error }
        guard let writtenURL else { throw UserFacingError(message: "Die Datei konnte nicht angelegt werden.") }
        return writtenURL
    }

    static func temporaryPDF(data: Data, filename: String) throws -> URL {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("DokuScan-Freigabe", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let url = temp.appendingPathComponent(UUID().uuidString + "-" + filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var folders: [SavedFolder] = [] { didSet { persist(folders, key: "dokuscan.folders.v1") } }
    @Published var favorites: [FavoriteDestination] = [] { didSet { persist(favorites, key: "dokuscan.favorites.v1") } }
    @Published var preferences = ScanPreferences() { didSet { persist(preferences, key: "scanchris.preferences.v1") } }
    @Published var rules: [FilingRule] = [] { didSet { persist(rules, key: "scanchris.rules.v1") } }
    @Published var presets: [ScanPreset] = [] { didSet { persist(presets, key: "scanchris.presets.v1") } }
    @Published var records: [SavedRecord] = [] { didSet { persist(records, key: "scanchris.records.v1") } }
    @Published var merchantAliases: [MerchantAlias] = [] { didSet { persist(merchantAliases, key: "scanchris.merchants.v1") } }
    @Published var newerTestFlightBuild = false

    init() {
        folders = Self.load([SavedFolder].self, key: "dokuscan.folders.v1") ?? []
        favorites = Self.load([FavoriteDestination].self, key: "dokuscan.favorites.v1") ?? []
        preferences = Self.load(ScanPreferences.self, key: "scanchris.preferences.v1") ?? ScanPreferences()
        rules = Self.load([FilingRule].self, key: "scanchris.rules.v1") ?? []
        presets = Self.load([ScanPreset].self, key: "scanchris.presets.v1") ?? []
        records = Self.load([SavedRecord].self, key: "scanchris.records.v1") ?? []
        merchantAliases = Self.load([MerchantAlias].self, key: "scanchris.merchants.v1") ?? []
    }

    func addFolder(name: String, url: URL) throws {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folders.append(SavedFolder(name: title.isEmpty ? url.lastPathComponent : title, bookmark: bookmark))
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        favorites.removeAll { $0.folderID == id }
        rules.removeAll { $0.folderID == id }
        presets = presets.map { preset in
            var copy = preset
            if copy.folderID == id { copy.folderID = nil }
            return copy
        }
    }

    func addFavorite(_ destination: FavoriteDestination) {
        if !favorites.contains(where: { $0.kind == destination.kind && $0.folderID == destination.folderID && $0.email == destination.email }) {
            favorites.append(destination)
        }
    }

    func matchingRule(merchant: String, text: String) -> FilingRule? {
        guard preferences.routingEnabled else { return nil }
        // Händler und Bon-Kopf prüfen; Artikel oder Werbung weiter unten sollen
        // keine falsche Ablageregel auslösen.
        let header = text.components(separatedBy: .newlines).prefix(12).joined(separator: "\n")
        let value = (merchant + "\n" + header).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
        return rules.first { rule in
            let needle = rule.merchantContains.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            return needle.count >= 2 && value.contains(needle) && folders.contains(where: { $0.id == rule.folderID })
        }
    }

    func canonicalMerchant(for detected: String) -> String {
        let cleaned = detected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }
        let normalized = cleaned.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if let stored = merchantAliases.first(where: {
            let seen = $0.seen.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return seen == normalized || seen.contains(normalized) || normalized.contains(seen)
        }) { return stored.canonical }
        return cleaned
    }

    func rememberMerchant(detected: String, corrected: String) {
        let canonical = corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canonical.count >= 2 else { return }
        for name in [detected, canonical] {
            let seen = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard seen.count >= 2 else { continue }
            if let index = merchantAliases.firstIndex(where: { $0.seen.caseInsensitiveCompare(seen) == .orderedSame }) {
                merchantAliases[index].canonical = canonical
            } else { merchantAliases.append(MerchantAlias(seen: seen, canonical: canonical)) }
        }
    }

    func archive(pdf: Data, record: SavedRecord) throws {
        let url = try ArchiveStore.save(pdf: pdf, filename: record.storedFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw UserFacingError(message: "Die PDF-Kopie konnte nicht ins lokale Archiv geschrieben werden.")
        }
        records.append(record)
    }

    func deleteRecord(_ record: SavedRecord) {
        try? ArchiveStore.delete(filename: record.storedFile)
        records.removeAll { $0.id == record.id }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let encoded = try? JSONEncoder().encode(value) { UserDefaults.standard.set(encoded, forKey: key) }
    }
    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

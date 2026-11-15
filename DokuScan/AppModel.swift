import Foundation
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var folders: [SavedFolder] = [] {
        didSet { persist(folders, key: "dokuscan.folders.v1") }
    }
    @Published var favorites: [FavoriteDestination] = [] {
        didSet { persist(favorites, key: "dokuscan.favorites.v1") }
    }
    @Published var newerTestFlightBuild = false

    init() {
        folders = Self.load([SavedFolder].self, key: "dokuscan.folders.v1") ?? []
        favorites = Self.load([FavoriteDestination].self, key: "dokuscan.favorites.v1") ?? []
    }

    func addFolder(name: String, url: URL) throws {
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        folders.append(SavedFolder(name: name.isEmpty ? url.lastPathComponent : name, bookmark: bookmark))
    }

    func deleteFolder(_ id: UUID) {
        folders.removeAll { $0.id == id }
        favorites.removeAll { $0.folderID == id }
    }

    func addFavorite(_ destination: FavoriteDestination) {
        if !favorites.contains(where: { $0.kind == destination.kind && $0.folderID == destination.folderID && $0.email == destination.email }) {
            favorites.append(destination)
        }
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

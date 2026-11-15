import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var addEmail = false
    @State private var emailAddress = ""

    var body: some View {
        List {
            Section {
                if model.favorites.isEmpty {
                    ContentUnavailableView("Noch keine Favoriten", systemImage: "star", description: Text("Speichere Ordner und Versandarten für eine schnellere Auswahl."))
                }
                ForEach(model.favorites) { favorite in
                    Label(favorite.label, systemImage: symbol(for: favorite.kind))
                }
                .onDelete { offsets in model.favorites.remove(atOffsets: offsets) }
            } header: { Text("Meine Favoriten") } footer: {
                Text("Nach links wischen, um einen Favoriten zu löschen. Für App-Versand und AirDrop öffnet sich immer die iOS-Teilen-Ansicht.")
            }
            Section {
                Menu {
                    Button("iOS Teilen / AirDrop / Apps", systemImage: "square.and.arrow.up") {
                        model.addFavorite(FavoriteDestination(kind: .share, label: "Teilen und Apps"))
                    }
                    Button("E-Mail-Adresse", systemImage: "envelope") { addEmail = true }
                    if !model.folders.isEmpty { Divider() }
                    ForEach(model.folders) { folder in
                        Button(folder.name, systemImage: "folder") {
                            model.addFavorite(FavoriteDestination(kind: .folder, label: folder.name, folderID: folder.id))
                        }
                    }
                } label: {
                    Label("Favorit hinzufügen", systemImage: "plus.circle.fill")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DokuTheme.background)
        .navigationTitle("Favoriten")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
        .alert("E-Mail-Favorit", isPresented: $addEmail) {
            TextField("adresse@beispiel.de", text: $emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            Button("Hinzufügen") {
                let email = emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
                if email.contains("@"), email.contains(".") {
                    model.addFavorite(FavoriteDestination(kind: .email, label: "E-Mail: " + email, email: email))
                }
                emailAddress = ""
            }
            Button("Abbrechen", role: .cancel) { emailAddress = "" }
        } message: {
            Text("Die E-Mail wird nur als Empfänger vorgeschlagen. Senden muss immer von dir bestätigt werden.")
        }
    }
}

func symbol(for kind: FavoriteKind) -> String {
    switch kind {
    case .folder: "folder.fill"
    case .share: "square.and.arrow.up"
    case .email: "envelope.fill"
    }
}

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddFolder = false

    var body: some View {
        List {
            Section {
                if model.folders.isEmpty {
                    ContentUnavailableView("Noch keine Speicherorte", systemImage: "folder", description: Text("Füge einen Ordner aus der Dateien-App hinzu, z. B. iCloud Drive oder Dropbox."))
                } else {
                    ForEach(model.folders) { folder in
                        Label(folder.name, systemImage: "folder.fill")
                    }
                    .onDelete { offsets in
                        let foldersToRemove = offsets.map { model.folders[$0].id }
                        foldersToRemove.forEach { model.deleteFolder($0) }
                    }
                }
                Button {
                    showAddFolder = true
                } label: {
                    Label("Neuer Speicherort", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Speicherorte für Belege")
            } footer: {
                Text("Wähle einen Ordner in „Dateien“ aus. Dropbox ist möglich, wenn es dort als Speicherort eingerichtet ist. Zum Löschen einen Eintrag nach links wischen.")
            }

            Section("Weitere Einstellungen") {
                NavigationLink("Favorisiertes Speichern") { FavoritesView() }
                NavigationLink("Information und Datenschutz") { InformationView() }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DokuTheme.background)
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
        .sheet(isPresented: $showAddFolder) { NavigationStack { AddFolderView() } }
    }
}

struct AddFolderView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var showPicker = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Name in DokuScan") {
                TextField("z. B. Haushalt, Büro, Verein", text: $name)
                    .textInputAutocapitalization(.words)
                Text("Nach der Ordnerauswahl wird dieser Name beim Beleg-Scannen angezeigt.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Ordner in Dateien auswählen", systemImage: "folder.badge.plus")
                }
            } footer: {
                Text("Der Ordner muss bereits existieren. Im Dateiauswahldialog ggf. zuerst einen neuen Ordner erstellen.")
            }
        }
        .navigationTitle("Speicherort hinzufügen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } } }
        .sheet(isPresented: $showPicker) {
            FolderPicker(onPick: { url in
                showPicker = false
                do {
                    try model.addFolder(name: name, url: url)
                    dismiss()
                } catch { self.error = error.localizedDescription }
            }, onCancel: { showPicker = false })
        }
        .alert("Ordner konnte nicht gespeichert werden", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

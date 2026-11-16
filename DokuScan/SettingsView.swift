import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showAddFolder = false
    @State private var reminderPermissionHint = false

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

            Section {
                Toggle("07 · Automatische Ablageregeln", isOn: $model.preferences.routingEnabled)
                if model.preferences.routingEnabled {
                    NavigationLink("Ablageregeln bearbeiten") { FilingRulesView() }
                }
                Toggle("08 · Schlagwörter und Kategorien", isOn: $model.preferences.tagsEnabled)
                Toggle("10 · PDF-Inhalte schwärzen", isOn: $model.preferences.redactionEnabled)
                Toggle("12 · Rückgabe- und Garantieerinnerungen", isOn: $model.preferences.remindersEnabled)
                Toggle("14 · Scan-Vorlagen", isOn: $model.preferences.presetsEnabled)
                if model.preferences.presetsEnabled {
                    NavigationLink("Vorlagen bearbeiten") { ScanPresetsView() }
                }
            } header: {
                Text("Erweiterte Funktionen – einzeln aktivieren")
            } footer: {
                Text("Diese fünf Funktionen sind zunächst ausgeschaltet. Bestehende Scan-Abläufe bleiben unverändert. Erinnerungen benötigen die iOS-Mitteilungsberechtigung.")
            }

            Section("PDF-Qualität") {
                Picker("Dateigröße / Bildqualität", selection: $model.preferences.pdfQuality) {
                    ForEach(PDFQuality.allCases) { quality in Text(quality.rawValue).tag(quality) }
                }
                Text("Kompakt spart Speicherplatz. Auch bei komprimierten PDFs bleibt die erkannte Textebene durchsuchbar.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Weitere Einstellungen") {
                NavigationLink("Dokumentenarchiv und Ausgaben") { ArchiveView() }
                NavigationLink("Gelernte Händler verwalten") { MerchantMemoryView() }
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
        .onChange(of: model.preferences.remindersEnabled) { _, enabled in
            if enabled {
                Task {
                    if await ReminderService.requestPermission() {
                        for record in model.records { await ReminderService.schedule(for: record) }
                    } else { reminderPermissionHint = true }
                }
            } else {
                model.records.forEach { ReminderService.cancel(for: $0) }
            }
        }
        .alert("Mitteilungen nicht erlaubt", isPresented: $reminderPermissionHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Die Funktion ist aktiviert, aber iOS erlaubt momentan keine Erinnerungen. Erlaube Mitteilungen für Scanchris in den iPhone-Einstellungen.")
        }
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
            Section("Name in Scanchris") {
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

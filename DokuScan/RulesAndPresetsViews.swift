import SwiftUI

struct FilingRulesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showNew = false
    var body: some View {
        List {
            Section {
                if model.rules.isEmpty { Text("Noch keine Regeln angelegt.").foregroundStyle(.secondary) }
                ForEach(model.rules) { rule in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Enthält: \(rule.merchantContains)").font(.headline)
                        Text("→ " + (model.folders.first(where: { $0.id == rule.folderID })?.name ?? "Ordner fehlt"))
                            .font(.subheadline)
                        if !rule.category.isEmpty { Text("Kategorie: " + rule.category).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .onDelete { model.rules.remove(atOffsets: $0) }
            } header: {
                Text("Regeln")
            } footer: {
                Text("Regeln gelten nur für «Beleg mit Ablageregeln». Die erste passende Regel gewinnt. Bei fehlendem Treffer kann der Zielordner in der Prüfansicht gewählt werden.")
            }
            Button("Neue Regel hinzufügen", systemImage: "plus") { showNew = true }
                .disabled(model.folders.isEmpty)
        }
        .navigationTitle("Ablageregeln")
        .sheet(isPresented: $showNew) { NavigationStack { NewRuleView() } }
    }
}

private struct NewRuleView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var category = ""
    @State private var folderID: UUID?
    var body: some View {
        Form {
            Section("Wenn OCR / Händler Folgendes enthält") {
                TextField("z. B. REWE", text: $keyword)
                    .textInputAutocapitalization(.characters)
            }
            Section("Automatisch ablegen in") {
                Picker("Zielordner", selection: $folderID) {
                    ForEach(model.folders) { folder in Text(folder.name).tag(folder.id as UUID?) }
                }
                if model.preferences.tagsEnabled {
                    TextField("Kategorie (optional)", text: $category)
                }
            }
        }
        .onAppear { if folderID == nil { folderID = model.folders.first?.id } }
        .navigationTitle("Neue Ablageregel")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sichern") {
                    guard let folderID else { return }
                    model.rules.append(FilingRule(merchantContains: keyword.trimmingCharacters(in: .whitespacesAndNewlines), folderID: folderID, category: category))
                    dismiss()
                }
                .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || folderID == nil)
            }
        }
    }
}

struct ScanPresetsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showNew = false
    var body: some View {
        List {
            Section {
                if model.presets.isEmpty { Text("Noch keine Vorlagen angelegt.").foregroundStyle(.secondary) }
                ForEach(model.presets) { preset in
                    VStack(alignment: .leading) {
                        Text(preset.name).font(.headline)
                        Text(preset.kind == "receipt" ? "Beleg" : "Dokument")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { model.presets.remove(atOffsets: $0) }
            } header: {
                Text("Vorlagen")
            } footer: {
                Text("Vorlagen erscheinen nur bei aktivierter Funktion im Startbildschirm. Die normalen Scan-Schaltflächen bleiben erhalten.")
            }
            Button("Neue Vorlage", systemImage: "plus") { showNew = true }
        }
        .navigationTitle("Scan-Vorlagen")
        .sheet(isPresented: $showNew) { NavigationStack { NewPresetView() } }
    }
}

private struct NewPresetView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind = "document"
    @State private var folderID: UUID?
    @State private var category = ""
    @State private var filenameTemplate = ""
    var body: some View {
        Form {
            TextField("Vorlagenname, z. B. Tankbeleg", text: $title)
            Picker("Scannen als", selection: $kind) {
                Text("Dokument").tag("document")
                Text("Beleg").tag("receipt")
            }
            if kind == "receipt" {
                Picker("Zielordner", selection: $folderID) {
                    Text("Zielordner wählen").tag(nil as UUID?)
                    ForEach(model.folders) { folder in Text(folder.name).tag(folder.id as UUID?) }
                }
            }
            if model.preferences.tagsEnabled { TextField("Kategorie (optional)", text: $category) }
            Section("Dateiname (optional)") {
                TextField("{datum}_{titel}", text: $filenameTemplate)
                Text("Platzhalter: {datum}, {titel}, {firma}, {artikel}, {betrag}, {nr}. Ohne Angabe gilt der bisherige automatische Dateiname.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Neue Vorlage")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sichern") {
                    model.presets.append(ScanPreset(name: title.trimmingCharacters(in: .whitespacesAndNewlines), kind: kind, folderID: kind == "receipt" ? folderID : nil, category: category, filenameTemplate: filenameTemplate))
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (kind == "receipt" && folderID == nil))
            }
        }
    }
}

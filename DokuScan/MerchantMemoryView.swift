import SwiftUI

struct MerchantMemoryView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List {
            Section {
                if model.merchantAliases.isEmpty {
                    ContentUnavailableView("Noch keine Händlernamen", systemImage: "storefront", description: Text("Korrigiere bei einem Beleg den Händler und speichere ihn. Scanchris merkt sich den Namen lokal für spätere Erkennungen."))
                }
                ForEach(model.merchantAliases) { alias in
                    VStack(alignment: .leading) {
                        Text(alias.canonical).font(.subheadline.bold())
                        if alias.seen != alias.canonical {
                            Text("Erkannt als: " + alias.seen).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { model.merchantAliases.remove(atOffsets: $0) }
            } header: {
                Text("Gemerkte Namen")
            } footer: {
                Text("Namen werden nur auf diesem iPhone gespeichert. Zum Löschen einen Eintrag nach links wischen. Das Archiv und bereits gespeicherte PDFs bleiben unverändert.")
            }
        }
        .navigationTitle("Händler-Erinnerung")
    }
}

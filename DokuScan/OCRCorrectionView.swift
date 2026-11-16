import SwiftUI

struct OCRCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onSave: (String) -> Void

    init(text: String, onSave: @escaping (String) -> Void) {
        _text = State(initialValue: text)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Erkannten Text korrigieren. Wenn möglich die Anzahl und Reihenfolge der Zeilen beibehalten, damit die Positionen im durchsuchbaren PDF stimmen.")
                .font(.footnote).foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(DokuTheme.background.ignoresSafeArea())
        .navigationTitle("OCR korrigieren")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Übernehmen") { onSave(text); dismiss() }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

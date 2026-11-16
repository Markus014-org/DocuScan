import SwiftUI

/// Hilfe zur aktuell implementierten Scanchris-Oberfläche.
/// Die Seite informiert; sie verändert weder Scanabläufe noch Einstellungen.
struct InformationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header("Scanchris – schnell starten", icon: "doc.text.viewfinder")
                paragraph("Scanchris scannt Dokumente und Kassenbons, erkennt Text direkt auf dem iPhone und erstellt mehrseitige, durchsuchbare A4-PDFs. Die beiden ursprünglichen Scanwege bleiben erhalten. Erweiterte Funktionen findest du im Menü oder in den Einstellungen.")

                header("Dokument scannen", icon: "doc.text")
                paragraph("Auf der Startseite „Dokument scannen“ wählen. Eine oder mehrere Seiten im Apple-Dokumentenscanner aufnehmen und den Scan abschließen. Danach kannst du Seiten prüfen, vergrößern, drehen, beschneiden, löschen oder weitere Seiten hinzufügen.")
                paragraph("Der Dateiname wird vorgeschlagen und kann frei geändert werden. „Speichern“ öffnet die iOS-Teilen-Ansicht: Dort kannst du „In Dateien sichern“, Mail, AirDrop oder andere Apps auswählen. „Favorisiertes Speichern“ verwendet einen zuvor angelegten Favoriten. Beim Speichern entsteht zusätzlich eine lokale Archivkopie.")

                header("Beleg scannen", icon: "receipt")
                paragraph("Wie bisher zunächst einen eingerichteten Zielordner auswählen, anschließend den Beleg scannen. Prüfe Firma, teuerste Position, Datum, Gesamtbetrag und Mehrwertsteuer. Die Erkennung macht Vorschläge, keine verbindliche Rechnungsprüfung. Mit „Dateinamen aus diesen Feldern übernehmen“ aktualisierst du den Vorschlag.")
                paragraph("„Speichern“ legt die PDF im zuvor gewählten Ordner ab und erstellt eine zusätzliche Kopie im lokalen Scanchris-Archiv. Die laufende dreistellige Nummer richtet sich nach den Dateien im Zielordner. Bereits vorhandene gleichnamige Dateien werden nicht überschrieben.")

                if model.preferences.routingEnabled {
                    header("Beleg mit Ablageregeln", icon: "arrow.triangle.branch")
                    paragraph("Dieser dritte Scan-Button erscheint nur, wenn du unter Einstellungen „07 · Automatische Ablageregeln“ aktiviert hast. Lege dort zunächst Regeln wie „REWE → Lebensmittel“ und die passenden Speicherorte an. Beim Scan wird anhand des erkannten Händlers und Bonkopfs der Zielordner vorgeschlagen. Die erste passende Regel gewinnt. In der Prüfansicht kannst du den Ordner vor dem Speichern ändern. Findet sich keine Regel, wählst du den Ordner selbst.")
                } else {
                    header("Optional: Beleg mit Ablageregeln", icon: "arrow.triangle.branch")
                    paragraph("Wenn du Belege automatisch nach Händler ablegen möchtest, aktiviere unter Einstellungen „07 · Automatische Ablageregeln“ und lege mindestens eine Regel an. Erst dann erscheint auf der Startseite der Button „Beleg mit Ablageregeln“. Das normale Belegscannen bleibt unverändert.")
                }

                header("01 · Intelligentere Belegerkennung", icon: "text.magnifyingglass")
                paragraph("Die OCR wertet bei Belegen nicht nur Textzeilen aus, sondern berücksichtigt auch die Position erkannter Texte und Preise. So können Händler und teuerste Artikelposition besser vorgeschlagen werden. Summen, Steuern und Zahlungsangaben sollen möglichst nicht als Artikel gelten. Bitte alle Werte vor dem Speichern kontrollieren.")

                header("02 · OCR-Text korrigieren", icon: "text.badge.checkmark")
                paragraph("In der Prüfansicht „OCR-Text korrigieren“ öffnen, Text überarbeiten und übernehmen. Wenn möglich Zeilenanzahl und -reihenfolge beibehalten, damit die unsichtbare PDF-Textebene an den richtigen Stellen liegt. Korrekturen wirken auf den erkannten Text; das fotografierte Bild wird dadurch nicht umgeschrieben.")

                header("03 · Scanqualität prüfen", icon: "viewfinder")
                paragraph("Bei auffälliger Bildqualität zeigt die Prüfansicht Hinweise, zum Beispiel zu geringer Auflösung, Dunkelheit, Überbelichtung oder niedrigem Kontrast. Das sind Warnungen, keine Garantie für eine perfekte Texterkennung. Du kannst einen Scan auch mit Hinweis speichern.")

                header("04 · Bilder und PDFs importieren", icon: "doc.badge.plus")
                paragraph("Im Menü „PDF oder Bild importieren“ oder „Fotos importieren“ wählen. Importierte Seiten werden wie gescannte Dokumente geprüft und per OCR verarbeitet. Ein Import ist auf maximal 30 Seiten begrenzt; vorhandene PDFs werden dafür als Bildseiten eingelesen und beim Speichern neu erzeugt.")

                header("05 · Doppelte Dokumente erkennen", icon: "doc.on.doc")
                paragraph("Scanchris vergleicht neue Dokumente mit Einträgen im lokalen Archiv. Bei Belegen werden Händler, Datum und Gesamtbetrag genutzt, bei Dokumenten längere OCR-Texte. Wird eine mögliche Dublette erkannt, kannst du den Vorgang abbrechen oder trotzdem speichern. Nicht jede Doppelung wird erkannt.")

                header("06 · Dokumentenarchiv und Suche", icon: "tray.full")
                paragraph("Über das Menü „Archiv & Ausgaben“ kannst du gespeicherte Archivkopien öffnen, nach Dateinamen und OCR-Inhalt suchen sowie Dokumente erneut teilen. Mit „Nur Belege“ schränkst du die Liste ein. Das Archiv liegt lokal in der App und ist von Dateien in Dropbox, iCloud oder anderen gewählten Ordnern getrennt. Das Löschen eines Archiveintrags löscht nicht automatisch die extern gespeicherte Originaldatei.")

                header("07 · Automatische Ablageregeln (optional)", icon: "arrow.triangle.branch")
                paragraph("In Einstellungen einschalten und über „Ablageregeln bearbeiten“ einen Suchbegriff für den Händler sowie einen Zielordner festlegen. Die Regeln werden nur bei „Beleg mit Ablageregeln“ verwendet. Beim normalen „Beleg scannen“ bestimmst du den Zielordner weiterhin selbst.")

                header("08 · Kategorien und Schlagwörter (optional)", icon: "tag")
                paragraph("Erst nach Aktivierung in Einstellungen erscheinen zusätzliche Eingabefelder für Kategorie und kommagetrennte Schlagwörter in der Prüfansicht. Diese Angaben werden im lokalen Archiv gespeichert und können bei der Suche genutzt werden. Im Archiv kannst du dann auch nach Kategorien filtern.")

                header("09 · PDF-Qualität und Dateigröße", icon: "doc.zipper")
                paragraph("Unter Einstellungen → PDF-Qualität zwischen „Kompakt“, „Ausgewogen“ und „Hohe Qualität“ wählen. Kompakte Dateien benötigen weniger Speicherplatz, können aber feine Schrift im Bild weniger scharf darstellen. Die durchsuchbare OCR-Textebene bleibt Bestandteil des PDFs.")

                header("10 · Inhalte schwärzen (optional)", icon: "rectangle.dashed")
                paragraph("Nach Aktivierung unter Einstellungen steht in der Prüfansicht die Schwärzungsfunktion bereit. Ziehe schwarze Rechtecke über vertrauliche Stellen und übernimm die Bearbeitung. Scanchris verändert die Bildpixel und führt anschließend die OCR neu aus, damit alter verdeckter Text nicht aus der vorherigen Texterkennung in die neue PDF übernommen wird. Kontrolliere den gesamten Inhalt vor dem Weitergeben und speichere das ungeschwärzte Original bei Bedarf zuvor separat.")

                header("11 · Ausgabenübersicht und CSV", icon: "chart.bar.xaxis")
                paragraph("Im Archiv erscheinen für erkannte Belege Ausgaben nach Monaten und Händlern sowie eine Schätzung der Umsatzsteuer bei eindeutigen 7 % oder 19 %. Mit „Belegdaten als CSV exportieren“ kannst du die erfassten Belegangaben als Tabelle weitergeben. OCR-Fehler, gemischte Steuersätze oder fehlende Beträge können die Auswertung verfälschen; sie ersetzt keine Buchhaltung.")

                header("12 · Rückgabe- und Garantieerinnerungen (optional)", icon: "bell")
                paragraph("Aktiviere die Funktion unter Einstellungen und erlaube bei Bedarf iOS-Mitteilungen. Danach kannst du bei Belegen Rückgabefrist und Garantieende individuell einschalten und Daten festlegen. Die App plant lokale Hinweise grundsätzlich drei Tage vor einer Rückgabefrist beziehungsweise 30 Tage vor Garantieende; liegt dieser Zeitpunkt bereits in der Vergangenheit, wird der Termin selbst verwendet. Ohne Mitteilungsberechtigung erhältst du keine Hinweise.")

                header("13 · Häufige Händler wiedererkennen", icon: "storefront")
                paragraph("Wenn du beim Beleg einen erkannten Firmennamen korrigierst und speicherst, kann sich Scanchris diese Zuordnung lokal merken und künftig vorschlagen. Unter Einstellungen → „Gelernte Händler verwalten“ kannst du diese Zuordnungen ansehen und löschen. Bereits gespeicherte PDFs bleiben dadurch unverändert.")

                header("14 · Scan-Vorlagen (optional)", icon: "square.stack")
                paragraph("Aktiviere „Scan-Vorlagen“ unter Einstellungen und lege eine Vorlage mit Namen, Scanart und gegebenenfalls Zielordner oder Dateinamensschema an. Sobald mindestens eine Vorlage vorhanden ist, erscheint auf der Startseite „Scan-Vorlage starten“. Der normale Scanweg bleibt weiterhin verfügbar. Unterstützte Platzhalter: {datum}, {titel}, {firma}, {artikel}, {betrag} und {nr}.")

                header("Speicherorte, Dropbox und Favoriten", icon: "folder")
                paragraph("Unter Einstellungen → „Neuer Speicherort“ einen bereits vorhandenen Ordner aus der iOS-Dateien-App auswählen und in Scanchris benennen. Dropbox kann über die installierte Dropbox-App als Speicheranbieter in „Dateien“ eingebunden werden. Scanchris besitzt keine eigene Dropbox-Anmeldung; die Synchronisierung erfolgt durch den jeweiligen Dateianbieter. Unter „Favoriten“ kannst du Ordner, E-Mail-Empfänger oder die Teilen-Ansicht als Schnellziel hinterlegen.")

                header("Datenschutz und Grenzen", icon: "lock.shield")
                paragraph("Die OCR verarbeitet Scans lokal auf dem iPhone; Scanchris betreibt keinen eigenen Server zum Hochladen von Dokumenten. Das zusätzliche Archiv speichert PDF-Kopien im privaten App-Speicher, während Ordner, Favoriten, Einstellungen, Regeln, Händlerzuordnungen und Archiv-Metadaten lokal verwaltet werden. Beim Teilen, beim Speichern in Cloud-Ordnern oder beim Versand gelten die Datenschutz- und Synchronisierungsbedingungen des gewählten Dienstes.")
                paragraph("Scanchris bietet keine eigene Ende-zu-Ende-Verschlüsselung. Die iOS-Systemschutzmechanismen gelten für lokale App-Daten. Die optionale TestFlight-Versionsprüfung lädt eine öffentliche Versionsdatei über HTTPS, überträgt dabei aber keine Scaninhalte. Schlechte Beleuchtung, Beleglayouts, Handschrift und OCR-Fehler können die Ergebnisse beeinflussen; bitte wichtige Dokument- und Belegdaten prüfen.")
            }
            .padding(18)
        }
        .background(DokuTheme.background.ignoresSafeArea())
        .navigationTitle("Information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
            }
        }
    }

    private func header(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(DokuTheme.ink)
            .padding(.top, 8)
    }

    private func paragraph(_ content: String) -> some View {
        Text(content)
            .font(.subheadline)
            .foregroundStyle(DokuTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }
}

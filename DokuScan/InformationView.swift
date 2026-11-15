import SwiftUI

struct InformationView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header("Willkommen bei Scanchris", icon: "doc.text.viewfinder")
                paragraph("Scanchris erstellt aus abfotografierten Seiten mehrseitige, durchsuchbare PDF-Dateien im DIN-A4-Format. Der Scanner erkennt Dokumentkanten, korrigiert die Perspektive und unterstützt das Scannen mehrerer Seiten hintereinander.")

                header("1 · Dokument scannen", icon: "doc.text")
                paragraph("Auf der Startseite „Dokument scannen“ antippen. Im Apple-Scanner die Seiten nacheinander aufnehmen. Wenn die automatische Aufnahme angeboten wird, hältst du das iPhone ruhig über die Seite. Kontrolliere unten im Scanner die aufgenommenen Seiten und beende den Scan mit „Sichern“ bzw. „Fertig“.")
                paragraph("Danach Seite für Seite mit den Miniaturbildern auswählen, mit zwei Fingern vergrößern und über „Bearbeiten“ beschneiden, um 90° drehen oder löschen. Über „Weitere Seiten“ kannst du den Scan fortsetzen. Im Abschnitt „Erkannter Text (OCR)“ lässt sich die Texterkennung prüfen.")
                paragraph("Der vorgeschlagene Dateiname beginnt mit JJMMTT und danach einem erkannten Stichwort, z. B. 261114_Vertrag.pdf. Du kannst ihn frei ändern. „Speichern“ öffnet die iOS-Teilen-Ansicht. Dort findest du „In Dateien sichern“, E-Mail, AirDrop und weitere installierte Apps.")

                header("2 · Beleg scannen", icon: "receipt")
                paragraph("„Beleg scannen“ öffnen und einen hinterlegten Speicherort auswählen. Der Scan erfolgt wie beim Dokument. Die App liest die PDF-Dateinamen im gewählten Ordner und erhöht die größte dreistellige Anfangsnummer um 1.")
                paragraph("Aus dem erkannten Text werden Aussteller, vermutlich teuerste Artikelposition, Belegdatum, Gesamtbetrag und Mehrwertsteuer als Vorschlag ermittelt. Prüfe diese Felder unbedingt: Die OCR kann Preise, Firmennamen und Steuersätze verwechseln. Mit „Dateinamen aus diesen Feldern übernehmen“ wird der Vorschlag neu erstellt. Auch den gesamten Dateinamen kannst du direkt bearbeiten.")
                paragraph("Das Format lautet 017_Firma_Artikel_14.11.2026_(41,32 - 19%).pdf. Unter dem Dateinamen wird die zuletzt gespeicherte Datei mit der höchsten laufenden Nummer angezeigt. „Speichern“ legt die PDF direkt im ausgewählten Ordner ab. Existiert derselbe Dateiname bereits, wird eine Endung ergänzt, statt die Datei zu überschreiben.")

                header("3 · Speicherorte und Dropbox", icon: "folder")
                paragraph("Im Menü unter „Einstellungen“ → „Neuer Speicherort“ einen Namen eingeben und dann in der iOS-Dateien-App einen bestehenden Ordner auswählen. Der angezeigte Name kann z. B. „Privat“, „Büro“ oder „Verein“ lauten. Entfernen: einen Speicherort in den Einstellungen nach links wischen.")
                paragraph("Dropbox funktioniert über die offizielle Dropbox-App als Speicheranbieter der iOS-Dateien-App. Aktiviere Dropbox dort unter „Durchsuchen“ und wähle anschließend den Dropbox-Ordner aus. Scanchris hat keine eigene Dropbox-Anmeldung. Die Synchronisierung eines dort abgelegten Dokuments erfolgt durch den Dateianbieter, nicht durch Scanchris. Bei fehlendem Internet kann die Synchronisierung verzögert sein.")

                header("4 · Favorisiertes Speichern", icon: "star")
                paragraph("In „Favoriten“ kannst du deine Ordner sowie „Teilen und Apps“ oder einen E-Mail-Empfänger dauerhaft hinterlegen. Bei „Dokument scannen“ wählst du „Favorisiertes Speichern“ und danach den Favoriten. Ordner werden direkt beschrieben. Für E-Mails öffnet sich das E-Mail-Verfassenfenster, wenn Apple Mail eingerichtet ist; andernfalls öffnet sich die Teilen-Ansicht. Bei anderen Apps und AirDrop erfolgt die Auswahl aus Sicherheitsgründen weiterhin in der iOS-Teilen-Ansicht. Favoriten lassen sich durch Wischen löschen.")

                header("5 · OCR und PDF", icon: "text.viewfinder")
                paragraph("Die Texterkennung verwendet Apples Vision-Framework lokal auf dem iPhone. Der Scan wird als Bild in die PDF gelegt; erkannter Text wird als unsichtbare Textschicht an den passenden Stellen eingebettet. Damit kann der PDF-Text von geeigneten PDF-Apps durchsucht und kopiert werden. Die A4-Seite wird bei abweichendem Seitenverhältnis nicht gestreckt, sondern passend eingepasst.")

                header("6 · Datenschutz und Verschlüsselung", icon: "lock.shield")
                paragraph("Die App sendet Scans und OCR-Texte nicht an einen Scanchris-Server. Ordnernamen, Favoriten und die Zugriffs-Lesezeichen für gewählte Ordner werden lokal in den App-Einstellungen (UserDefaults) gespeichert; exportierte Dokumente liegen ausschließlich dort, wo du sie ablegst. Für temporäre Freigaben erzeugt Scanchris PDF-Dateien im temporären App-Verzeichnis.")
                paragraph("Scanchris implementiert keine eigene Ende-zu-Ende-Verschlüsselung. Der App-Sandbox-Schutz und die systemeigene Datenverschlüsselung/Data Protection von iOS gelten für lokale Daten. Dateien auf iCloud Drive oder Dropbox unterliegen der jeweiligen Verschlüsselung, Übertragung und Synchronisierung des Anbieters. Über deren Ende-zu-Ende-Verschlüsselung trifft Scanchris keine Zusage.")
                paragraph("Die Versionsprüfung ruft nur eine öffentliche HTTPS-JSON-Datei mit freigegebener TestFlight-Versions- und Buildnummer ab. Es werden keine gescannten Dokumente dafür übertragen. Die App meldet eine neue Version oben links in Türkis, sobald die veröffentlichte Nummer höher als die installierte ist. Der Hinweis erscheint nur, wenn die GitHub-Actions-Versionsveröffentlichung eingerichtet wurde.")

                header("7 · Grenzen und Tipps", icon: "lightbulb")
                paragraph("Kontrast, Beleuchtung und ruhiges Halten verbessern das Ergebnis. Die automatische Aufnahme wird durch Apples Scanner gesteuert; je nach iOS-Version oder Situation kann eine manuelle Auslösung nötig sein. QR-Codes, handgeschriebene Notizen, Mehrwertsteuer und komplizierte Rechnungen werden nicht immer zuverlässig erkannt. Ohne Zugriff auf den gewählten Speicherort bitte den Ordner erneut hinterlegen. Eine PDF ist durchsuchbar, aber kein rechtlich garantiert vollständig ausgelesenes Rechnungsdatenset.")
                paragraph("Scanchris enthält keine Eingabe von Uhrzeiten. Sollten später solche Felder hinzukommen, sind iOS-Rad-Zeitwähler vorgesehen.")
            }
            .padding(18)
        }
        .background(DokuTheme.background.ignoresSafeArea())
        .navigationTitle("Information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
    }

    private func header(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.headline)
            .foregroundStyle(DokuTheme.ink)
            .padding(.top, 8)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(DokuTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }
}

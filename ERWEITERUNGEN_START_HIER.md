# Scanchris – Erweiterungen 01–14

## Für die Installation in GitHub

Repository: <https://github.com/Markus014-org/DocuScan>, Branch `main`.

**Diese ZIP ist bereits auf dem bisherigen, funktionierenden Scanchris-Stand aufgebaut.**
Die Apple- und Fastlane-Konfiguration wurde nicht umgestellt. Die ursprüngliche
Scanner- und Belegspeicherung bleibt erhalten.

1. ZIP **entpacken** – nicht als ZIP-Datei in GitHub hochladen.
2. GitHub → Verzeichnis **`DokuScan`** → **Add file → Upload files**:
   sämtliche `.swift`-Dateien aus dem entpackten `DokuScan`-Verzeichnis hochladen
   und vorhandene Dateinamen überschreiben.
3. GitHub → Verzeichnis **`.github/workflows`** → `ci.yml` aus der ZIP hochladen
   und vorhandene Datei ersetzen. Die übrigen Workflows bitte **nicht** ersetzen.
4. GitHub → Verzeichnis **`scripts`** → `check_feature_contracts.py` aus der ZIP
   ergänzen. `tests/` enthält optionale lokale Regressionstests.
5. Optional die neue Anleitung `ERWEITERUNGEN_START_HIER.md` ins Repository-Hauptverzeichnis hochladen.
6. Unter **Actions → iOS Buildprüfung** prüfen, dass der Xcode-Build erfolgreich ist.
7. **Erst danach** **Scanchris – TestFlight hochladen** manuell starten.
8. In TestFlight auf dem iPhone mit echten Dokumenten/Belegen testen.

Falls GitHub eine neue Datei unter falschem Pfad ablegt: Ins richtige Verzeichnis
wechseln und nur die jeweiligen Dateien dorthin hochladen, wie bei den früheren
Workflows. Keine zusätzlichen `.swift`-Dateien ins Repository-Hauptverzeichnis legen.

## Startbildschirm bleibt schlank

- **Dokument scannen**: wie bisher scannen → prüfen → PDF teilen/speichern.
- **Beleg scannen**: wie bisher Zielordner wählen → scannen → prüfen → speichern.
- **Beleg mit Ablageregeln** erscheint **nur**, wenn in Einstellungen 07 aktiviert
  ist. OCR ermittelt den passenden Ordner; vor dem Speichern ist der Zielordner
  sichtbar und überschreibbar. Ohne passenden Treffer muss der Benutzer auswählen.
- **Scan-Vorlage starten** erscheint nur bei aktivierter Funktion 14 und
  mindestens einer gespeicherten Vorlage.
- **Archiv, importieren und Statistiken** befinden sich im Menü oben rechts.

## Funktionsübersicht

| Nr. | Umsetzung | Bedienung |
|---|---|---|
| 01 | Verbesserte Offline-Auswertung von Händler, Artikeln, Gesamtbetrag | Automatisch bei Belegen; Felder kontrollierbar |
| 02 | OCR-Text manuell korrigieren | Beleg/Dokument prüfen → Bearbeiten → OCR-Text korrigieren |
| 03 | Qualitätshinweise zu Auflösung, Helligkeit, Kontrast | Bei Auffälligkeiten in der Prüfansicht |
| 04 | Fotos und PDF importieren, OCR erzeugen | Startmenü → Fotos bzw. PDF/Bild importieren |
| 05 | Dublettenwarnung | Vor Speichern; Warnung kann bestätigt werden |
| 06 | Lokales Archiv mit PDF-Vorschau und Volltextsuche | Menü → Archiv & Ausgaben |
| 07 | Automatische Ablageregeln | Einstellung aktivieren → Regeln anlegen → dritter Startbutton |
| 08 | Kategorien und Tags | Einstellung aktivieren → Felder in Prüfansicht |
| 09 | 3 PDF-Komprimierungsstufen | Einstellungen → PDF-Qualität |
| 10 | Geschwärzte Bereiche dauerhaft ins Bild zeichnen | Einstellung aktivieren → Bearbeiten → Schwärzen |
| 11 | Monatliche Ausgabenübersicht und CSV | Archiv & Ausgaben |
| 12 | Rückgabe-/Garantiefristen (3 bzw. 30 Tage vorher) | Einstellung + iOS-Mitteilungen erlauben; Datumsfelder beim Beleg |
| 13 | Häufige Händlernamen merken | Nach korrigiertem Händlername beim Speichern; lokal |
| 14 | Eigene Scan-Vorlagen inkl. Dateinamens-Platzhaltern | Einstellung aktivieren → Vorlagen verwalten → Startmenü |

## Besonders wichtig: Einstellungen 07 / 08 / 10 / 12 / 14

Alle fünf Schalter sind **nach Installation zunächst AUS** und separat schaltbar.
Regeln/Vorlagen werden erst bei aktivem Schalter angeboten. Schwärzen wird
nur dann angezeigt. Schlagwörter/Kategorien sind ohne Aktivierung nicht
anwählbar. Bestehende Erinnerungen werden beim Ausschalten abbestellt.

## Daten- und Produktgrenzen

- Das Archiv legt beim Erstellen/Teilen einer PDF zusätzlich eine **lokale
  Kopie** in `Application Support/Scanchris-Archiv` an. Diese ist unabhängig
  von iCloud/Dropbox-Dateien und wird **nicht automatisch synchronisiert**.
  Eine abgebrochene iOS-Teilen-Aktion erzeugt trotzdem einen Archivintrag.
- Löschen aus dem Archiv entfernt nur die lokale Archivkopie, **nicht** eine
  zuvor in Dropbox/iCloud gespeicherte Datei.
- Bereits vorhandene alte PDFs werden **nicht automatisch indexiert**.
- Die Dublettenprüfung ist eine Heuristik aus Händler, Datum und Betrag bzw.
  OCR-Text; keine garantierte Bildgleichheitsprüfung.
- PDF-Import rendert bis zu 30 Seiten als Bilder und führt neue OCR durch;
  eingebettete Formulare oder vorhandene digitale Unterschriften bleiben nicht
  automatisch erhalten.
- Die Qualitätsbewertung ist nur eine Warnung, keine automatische Bildkorrektur.
- Die Händlererkennung ist heuristisch. Falsche Werte lassen sich vor dem
  Speichern korrigieren.
- Schwärzen verändert Pixel; der verdeckte Text wird durch erneute OCR auch
  aus der neu erzeugten Textebene ausgeschlossen. Trotzdem das exportierte PDF
  bei vertraulichen Dokumenten kontrollieren.
- Mitteilungen werden lokal über iOS vorgemerkt. Ohne Berechtigung oder nach
  Deinstallation werden keine Erinnerungen ausgelöst.
- CSV exportiert bestehende lokale Belegmetadaten, nicht fremde Kontoauszüge.

## Tests

Im Paket liegen Parser-Regressionstests und eine statische Prüfung der
Funktions-Verknüpfungen. Die Swift-Dateien wurden syntaktisch analysiert.
**Die gesamte App wurde in dieser Umgebung nicht mit Xcode gebaut und nicht
auf einem echten iPhone getestet.** Der GitHub-Actions-Build ist verpflichtend.

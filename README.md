# Scanchris – iPhone-Dokumentenscanner mit OCR und TestFlight

Scanchris ist eine native iOS-17+-App mit Mehrseiten-Scanner, lokalem OCR,
durchsuchbaren DIN-A4-PDF-Dateien, Belegbenennung und Speicherzielen über
die iOS-Dateien-App einschließlich konfigurierten Dropbox-Dateianbietern.

- **Anzeigename:** Scanchris
- **Apple Bundle-ID:** `de.markus014.scanchris`
- **App Store Connect:** App Scanchris (SKU `SCANCHRIS-IOS-001`)
- **GitHub-Repository:** `Markus014-org/DocuScan`
- **Interner Xcode-Projekt-/Scheme-Name:** `DokuScan` (bewusst unverändert)

## Upload und Einrichtung

Bitte zunächst **`START_HIER.md`** lesen. Das Repository wird für die gleichen
organisationsweiten Fastlane-/Match-Secrets eingerichtet wie das bestehende
Projekt `Markus014-org/TherDia`. Es müssen keine Apple-Schlüssel als Dateien
in das Repository geladen werden.

Benötigte Organisations-Secrets:
`TEAMID`, `GH_PAT`, `MATCH_PASSWORD`, `FASTLANE_KEY_ID`, `FASTLANE_ISSUER_ID`,
`FASTLANE_KEY`.

Benötigte Repository-Variable: `BUNDLE_ID=de.markus014.scanchris`.

### Workflows

- `iOS Buildprüfung`: erstellt einen unsignierten Simulator-Build bei Push.
- `Scanchris – Apple-Zugänge prüfen`: manueller Test, ob die Secrets und das
  Match-Repository erreichbar sind (prüft noch nicht Apples Signierung).
- `Scanchris – TestFlight hochladen`: erstellt mit Fastlane Match ein
  App-Store-Profil für die neue App-ID, archiviert und lädt eine IPA hoch.
- `Scanchris – verfügbare TestFlight-Version veröffentlichen`: optionaler
  30-Minuten-Abgleich, benötigt zusätzlich `ASC_BETA_GROUP_ID` und GitHub Pages.

Die signing-spezifische Fastlane-Konfiguration befindet sich in `fastlane/`.
Das Passwort und die privaten Schlüssel werden **niemals committed**.

## Funktionen

- Automatische Dokumenterkennung und Mehrseiten-Scan via VisionKit
- Seitenvorschau und Korrektur
- OCR-Texterkennung auf dem Gerät
- Durchsuchbare DIN-A4-PDFs
- Dokument- und Beleg-Dateinamen mit editierbaren Feldern
- Speichern und Teilen via iOS-Dateien-App
- Favorisierte Speicherziele
- Hinweise zu Datenschutz und Synchronisierung in der App
- Türkiser TestFlight-Update-Hinweis nach Einrichtung von Pages und Beta-Gruppe

## Hinweise

Der Swift-Code wurde zuvor im ursprünglichen Repository erfolgreich für
einen iOS-Simulator kompiliert. Die hier vorgenommenen Anpassungen an Name,
Fastlane und Signierung sind **noch nicht** mit einem signierten iOS-Release
getestet worden. Nicht jeder erfolgreiche Upload ist sofort für TestFlight-
Tester verfügbar; Apple muss den Build zunächst verarbeiten.

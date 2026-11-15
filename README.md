# DokuScan – iPhone-App mit OCR, Belegablage und TestFlight

Native **SwiftUI / VisionKit / Vision / UIKit**-App ab **iOS 17**, mit orangenem
App-Symbol und hell- bis mittelgrauer Benutzeroberfläche. Enthalten sind alle
Quelldateien und GitHub-Actions-Workflows. Für einen tatsächlich installierbaren
TestFlight-Build werden **ein kostenpflichtiges Apple Developer Program,
App-Store-Connect-Zugriff und eigene Signierschlüssel** benötigt.

**Wichtig:** Dieses Paket wurde programmatisch auf vollständige Dateien,
Swift-Syntax und Python-Tests geprüft. Ein echter iOS-Build oder ein Upload zu
Apple kann in der hier verwendeten Linux-Umgebung **nicht** durchgeführt
werden. Den tatsächlichen Swift-/Signatur-Build führt danach GitHub Actions
auf einem macOS-Runner durch.

## Überblick

| Bereich | Umsetzung |
|---|---|
| Startseite | DokuScan, „Dokument scannen“, „Beleg scannen“, Menü |
| Scanner | Apples Dokumentenscanner mit Mehrseiten-Aufnahme, Kantenerkennung und Perspektivkorrektur |
| Seitenprüfung | Miniaturen, Seitenzähler, Zwei-Finger-Zoom, weitere Seiten |
| Bearbeiten | Zuschneiden mit vier Griffpunkten, 90° drehen, Seite löschen |
| OCR | Apple Vision lokal mit Deutsch/Englisch, OCR-Text zur Kontrolle |
| PDF | Mehrseitiges, bildbasiertes DIN-A4-PDF mit unsichtbarer durchsuchbarer Textebene |
| Dokumentname | `JJMMTT_Stichwort.pdf`, editierbar |
| Belegname | `NNN_Firma_Position_TT.MM.JJJJ_(Betrag - USt).pdf`, editierbar |
| Nummern | Höchste PDF-Anfangsnummer mit mindestens drei Ziffern im gewählten Ordner + 1 |
| Belegablage | Direkt in gewähltem Ordner in „Dateien“ (iCloud, „Auf meinem iPhone“, Dropbox-Dateianbieter) |
| Dokument exportieren | Standard-iOS-Teilen-Sheet für Dateien, Mail, AirDrop, Apps |
| Favoriten | Dateiordner, Teilen und E-Mail-Empfänger, dauerhaft lokal gespeichert und löschbar |
| Information | In-App-Anleitung inkl. Datenschutz, Verschlüsselung, Grenzen |
| TestFlight-Anzeige | Türkiser Hinweis oben links, sobald eine neuere freigegebene Version vorliegt |

Es gibt derzeit **keine Uhrzeit-Eingabefelder**, daher auch keine Uhrzeit-Picker.

## 1. Repository anlegen

1. Bei [GitHub](https://github.com/new) ein neues Repository z. B. `DokuScan` erstellen.
2. **Den Inhalt dieses Verzeichnisses** hochladen, sodass `project.yml`,
   `DokuScan/` und `.github/workflows/` im Repository-Wurzelverzeichnis liegen.
   Die ausgepackte ZIP-Datei nicht als Einzeldatei hochladen.
3. Branch `main` verwenden. Der Workflow **„iOS Buildprüfung“** kompiliert
   den Simulator-Build bei jedem Push und Pull Request. Er benötigt **keine
   Apple-Zugangsdaten**.
4. Optional auf einem Mac lokal `brew install xcodegen`, `xcodegen generate`
   und danach `open DokuScan.xcodeproj` ausführen.

Die Buildprüfung kann nach dem Upload über GitHub → **Actions** beobachtet
werden. Falls Apples APIs oder Swift-Compiler neue Anforderungen haben,
zeigt der Job die genaue Fehlermeldung.

## 2. Apple Developer und App Store Connect vorbereiten

1. Im [Apple Developer Portal](https://developer.apple.com/account) ein
   **explizites App ID / Bundle ID** anlegen, z. B. `de.meinefirma.DokuScan`.
2. In [App Store Connect](https://appstoreconnect.apple.com) unter „Apps“ eine
   iOS-App mit **genau dieser Bundle ID** und dem Namen „DokuScan“ anlegen.
3. Ein **Apple Distribution**-Zertifikat mit exportierbarem privaten Schlüssel
   erstellen und auf einem vertrauenswürdigen Mac als `.p12` exportieren.
4. Ein **App Store Distribution Provisioning Profile** für die Bundle ID
   erstellen und als `.mobileprovision` herunterladen.
5. In App Store Connect → Benutzer und Zugriff → Integrationen →
   App Store Connect API einen **Team-API-Schlüssel** mit ausreichend Rechten
   erstellen. Notieren: **Key ID**, **Issuer ID**, `.p8`-Datei.
6. In TestFlight eine **interne Testgruppe** (empfohlen für die eigene
   Installation) einrichten, deinen Apple-Account als Tester aufnehmen und
   die automatische Freigabe/Verteilung der Builds an diese Gruppe aktivieren.
   Alternativ ist eine externe Testgruppe möglich; dafür kann Apples
   Beta-App-Review erforderlich sein.
7. Die **Beta-Gruppen-ID** (`ASC_BETA_GROUP_ID`) beschaffen. Sie ist eine
   App-Store-Connect-API-Resource-ID (kein sichtbarer Gruppenname). Mit dem
   API-Schlüssel kann die ID über
   `GET https://api.appstoreconnect.apple.com/v1/betaGroups?filter[app]=APP_ID`
   ermittelt werden.

> Die .p12-, .p8- und .mobileprovision-Dateien **niemals committen** und
> niemals in der App einbetten. Sie gehören nur in GitHub Actions Secrets.

### GitHub Actions → Settings → Secrets and variables → Actions

Unter **Repository variables**:

| Name | Inhalt |
|---|---|
| `BUNDLE_ID` | Exakte App Bundle ID, z. B. `de.meinefirma.DokuScan` |
| `APPLE_TEAM_ID` | 10-stellige Apple Developer Team ID |
| `ASC_BETA_GROUP_ID` | ID der internen (oder externen) TestFlight-Testgruppe |

Unter **Repository secrets**:

| Name | Inhalt |
|---|---|
| `CERTIFICATE_BASE64` | Base64-kodierte **komplette** .p12-Datei |
| `CERTIFICATE_PASSWORD` | Exportpasswort der .p12-Datei |
| `MOBILEPROVISION_BASE64` | Base64-kodierte **komplette** .mobileprovision-Datei |
| `ASC_PRIVATE_KEY_BASE64` | Base64-kodierte **komplette** App Store Connect .p8-Datei |
| `ASC_KEY_ID` | API Key ID |
| `ASC_ISSUER_ID` | API Issuer ID |
| `KEYCHAIN_PASSWORD` | Selbst gewähltes langes zufälliges Kennwort für den temporären macOS-Keychain |

Beispiel zum Base64-Kodieren auf dem Mac (Ausgabe jeweils **ohne** Zeilenumbruch
als Secret eintragen):

```bash
base64 -i AppleDistribution.p12 | tr -d '\n'
base64 -i DokuScan.mobileprovision | tr -d '\n'
base64 -i AuthKey_ABC123XYZ.p8 | tr -d '\n'
```

**Tipp:** Für ein echtes Projekt die GitHub-Actions-Rechte auf die benötigten
Workflows beschränken und Schlüssel ggf. regelmäßig rotieren.

## 3. TestFlight-IPA hochladen

1. GitHub → Actions → **„TestFlight – Archivieren und hochladen“** →
   **Run workflow**.
2. Der Job benutzt einen macOS-26-Runner, installiert XcodeGen, richtet die
   Apple-Distribution-Signierung ein, erstellt ein Release-Archiv und eine
   `.ipa`, lädt diese mit Apples `altool` hoch und erhöht mit
   `github.run_number` die interne Buildnummer.
3. Apple verarbeitet den Upload zunächst. In App Store Connect → TestFlight
   den Buildstatus kontrollieren und ggf. Angaben zum Export-Compliance-Status
   oder Beta-Review ergänzen. Nicht jeder erfolgreiche Upload ist sofort für
   Tester installierbar.
4. Sobald dein Build deiner Testgruppe verfügbar ist, in der **TestFlight-App
   auf deinem iPhone** die Einladung öffnen und DokuScan installieren.

Eine signierte IPA kann nicht ohne die Apple-Portal-Schritte, die eigenen
Zertifikate und den TestFlight-Upload erstellt werden.

## 4. Türkiser Hinweis „Neue Version in TestFlight verfügbar“

Die App hat **keinen geheimen App-Store-Connect-Schlüssel** und darf ihn nicht
besitzen. Stattdessen liest ein separater öffentlicher Endpunkt ausschließlich
Versionsmetadaten:

```json
{
  "version": "1.0",
  "build": "23",
  "publishedAt": "2026-11-15T10:00:00+00:00"
}
```

**Einrichtung:**

1. GitHub → Actions → **„TestFlight – verfügbare Version veröffentlichen“** →
   **Run workflow**, sobald dein Build einer Testgruppe zugeteilt und für diese
   zum Testen bereit ist.
2. Der Workflow liest die Builds der konfigurierten Testgruppe über die
   **App Store Connect API**. Er berücksichtigt nur `processingState=VALID`,
   nicht abgelaufene Builds und einen passenden internen/externen
   Beta-Status (`READY_FOR_BETA_TESTING` oder `IN_BETA_TESTING`).
3. Er veröffentlicht danach `latest-build.json` im Branch **`gh-pages`**.
4. GitHub Repository → Settings → **Pages** → **Deploy from a branch** →
   Branch `gh-pages`, Verzeichnis `/ (root)` → Save.
5. Bei einem Repository `Nutzername/DokuScan` lautet der öffentliche Endpunkt
   `https://nutzername.github.io/DokuScan/latest-build.json`.
   **Dieser Endpunkt wird beim TestFlight-Build automatisch in die App
   eingetragen**; er muss nicht in Swift geändert werden.
6. Der Workflow überprüft die Testgruppe auch **alle 30 Minuten**. Nach
   erfolgreicher Veröffentlichung kann GitHub Pages kurz zum Aktualisieren
   brauchen. Der Hinweis erscheint bei einem App-Start oder wenn DokuScan
   wieder in den Vordergrund kommt, solange die veröffentlichte Version/Build
   neuer ist als die installierte.

Der Hinweis öffnet die TestFlight-App-Website. **Einschränkungen:** Die
Prüfung kann sehen, was für die gewählte **Testgruppe** freigegeben ist,
nicht ob ein individueller Apple-Account die Einladung bereits angenommen
hat. Private Repositories können je nach GitHub-Plan/Pages-Einstellungen
nicht öffentlich veröffentlichen. Die JSON-Datei enthält weder Dokumente
noch personenbezogene Daten oder geheime Schlüssel.

## 5. iPhone: tägliche Benutzung

### Dokument scannen

Startseite → **Dokument scannen** → alle Seiten im nativen Scanner aufnehmen
→ **Fertig** → Miniaturen/Zoom/Bearbeiten → vorgeschlagenen Dateinamen prüfen
→ **Speichern** → `In Dateien sichern` oder andere iOS-Aktion.

Für einen festen Ordner oder Empfänger: Startmenü → **Favoriten** → einen
Ordner, Teilen oder E-Mail hinzufügen → nach dem Scan
**Favorisiertes Speichern** wählen.

### Beleg scannen

Startseite → **Beleg scannen** → Speicherort wählen (oder **Neuer
Speicherort** → Einstellungen) → scannen → erkannte Belegdaten und OCR prüfen
→ bei Korrekturen **Dateinamen aus diesen Feldern übernehmen** → **Speichern**.

Der letzte nummerierte PDF-Name im selben Ordner steht unter dem Namensfeld.
Weitere Beispiele findest du in [`docs/DATEINAMEN.md`](docs/DATEINAMEN.md).

### Dropbox

Dropbox-App auf dem iPhone installieren und mit deinem Konto verbinden. In
**Dateien** → **Durchsuchen** → **…** → **Bearbeiten** → Dropbox als Ort
aktivieren. Dann DokuScan → Einstellungen → Neuer Speicherort → deinen
Dropbox-Ordner auswählen. Die iOS-Dateianbieter-API steuert den Zugriff;
Dropbox selbst steuert die Cloud-Synchronisierung. Bei manchen
Dateianbietern muss der Ordner nach einem Berechtigungs- oder Kontowechsel
neu eingerichtet werden.

## Datenschutz, Verschlüsselung, Grenzen

- **OCR läuft auf dem iPhone** mit Apple Vision (Deutsch/Englisch). Kein
  Drittanbieter-OCR-Service. PDF-Dateien gehen nicht zu einem DokuScan-Server.
- **Keine eigene Ende-zu-Ende-Verschlüsselung** in DokuScan. Die iOS-Sandbox
  und die iOS-Datenverschlüsselung schützen lokale App-Dateien entsprechend
  den Systemeinstellungen. iCloud/Dropbox haben eigene Sicherheits- und
  Synchronisierungsregeln.
- **Speicherorte und Favoriten** werden in `UserDefaults` gespeichert; bei
  Ordnern als Security-Scoped Bookmarks. Die Dateien selbst werden nur in
  ausgewählte Ordner exportiert. Temporäre PDFs für Teilen/E-Mail entstehen
  im temporären App-Container.
- **Fotos/Scans nicht automatisch zu iCloud hochgeladen**, es sei denn, du
  wählst einen iCloud- bzw. Dropbox-Ordner. Kein eigener Sync-Dienst.
- **OCR-/Beleg-Heuristiken nicht fehlerfrei**. Prüfe Betrag, Datum,
  Mehrwertsteuer, Firma und teuerste Position. Die App erstellt keine
  Buchhaltungs-/Steuerprüfung und erkennt nicht immer gemischte USt.
- **Scanner-Bedienelemente** sind die systemeigene Apple-VisionKit-Oberfläche.
  Automatisches Auslösen erfolgt, **soweit vom System angeboten**; die App
  kann Aufnahmezeitpunkt, Live-Miniaturen und automatische Kontrolle der
  Dokumentgröße nicht selbst erzwingen. Die Bilder werden anschließend
  ohne Verzerrung auf A4-Seiten eingepasst.
- **Ordner-Nummerierung** nutzt die Liste der PDFs des ausgewählten Ordners;
  sie ist nicht transaktionssicher bei mehreren Geräten, die gleichzeitig
  in den gleichen Ordner speichern. Existierende Dateinamen werden niemals
  still überschrieben, sondern um eine Suffixnummer erweitert.

## Technische Struktur

```text
DokuScan/                       SwiftUI-App, VisionKit-Scanner, OCR, PDF-Renderer
  Assets.xcassets/              AppIcon Orange/Türkis
.github/workflows/ci.yml        Kompilierung im Simulator, ohne Secrets
.github/workflows/testflight.yml  Signierung und Upload per altool
.github/workflows/refresh-testflight.yml  API-Abfrage und GitHub Pages
scripts/                        ExportPlist und TestFlight-Metadaten
site/                           Öffentliche statische Versionsseite
project.yml                     XcodeGen-Projektdefinition
```

Testskript:

```bash
python3 -m unittest discover -s tests -v
```

Nützliche Apple-Quellen:

- [VisionKit – Document Camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)
- [Zugriff auf Ordner über den iOS Document Picker](https://developer.apple.com/documentation/uikit/providing-access-to-directories)
- [App Store Connect – Builds hochladen](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [Builds für eine Beta-Gruppe abfragen](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betagroups-_id_-builds)
- [Build-Beta-Status](https://developer.apple.com/documentation/appstoreconnectapi/build-beta-details)

© 2026 DokuScan – Projektvorlage. Vor Produktiveinsatz zuerst auf einem
physischen iPhone mit deinen Beleg- und Cloud-Anbietern testen.

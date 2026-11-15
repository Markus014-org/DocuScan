# Upload der Änderungen über GitHub-Weboberfläche

Ziel: https://github.com/Markus014-org/DocuScan (Branch `main`).

**Wichtig:** Diese ZIP nicht als eine Datei in das Repository laden. Zuerst
entpacken und Dateien bzw. Verzeichnisse übernehmen.

Unbedingt ersetzen/hochladen:

- `project.yml`
- `.github/workflows/testflight.yml`
- `.github/workflows/refresh-testflight.yml`
- `.github/workflows/preflight.yml` (neu)
- `fastlane/Fastfile` (neu)
- `fastlane/Matchfile` (neu)
- `Gemfile` (neu)
- `DokuScan/HomeView.swift`
- `DokuScan/InformationView.swift`
- `DokuScan/SettingsView.swift`
- `DokuScan/PDFCreator.swift`

Die anderen Dateien können unverändert bleiben. Am einfachsten: Im gewünschten
GitHub-Ordner auf `Add file` → `Upload files` gehen, die zugehörigen Dateien
hineinziehen und mit `Commit changes` speichern. Wiederholen für `.github/workflows`,
`fastlane`, `DokuScan` und die Hauptverzeichnisebene.

**Nicht ausführen:** Das alte TestFlight-Workflow-Schema mit `ASC_KEY_ID`,
`CERTIFICATE_BASE64`, `MOBILEPROVISION_BASE64` etc. ist hier ersetzt worden.
Der neue Workflow verwendet die aus TherDia bekannten Organisations-Secrets.

Prüfen: `Actions` → `iOS Buildprüfung`; dann den manuellen Workflow
`Scanchris – Apple-Zugänge prüfen` und danach `Scanchris – TestFlight hochladen`.

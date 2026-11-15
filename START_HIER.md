# Scanchris – nächster Schritt (bestehendes GitHub-Repository)

Diese ZIP ist für **Markus014-org/DocuScan** vorbereitet. Der interne Xcode-Targetname
bleibt DokuScan, der Anzeigename ist **Scanchris**. Bundle-ID: `de.markus014.scanchris`.

1. ZIP entpacken. **Nicht die ZIP-Datei selbst** nach GitHub hochladen.
2. Die enthaltenen Verzeichnisse/Dateien in das vorhandene GitHub-Repository
   `https://github.com/Markus014-org/DocuScan` auf `main` übernehmen.
   Bestehende gleichnamige Dateien ersetzen. Der Ordner `.github` ist wichtig.
   Wenn die GitHub-Weboberfläche einzelne Ordner nicht übernimmt, Dateien in
   ihrem jeweiligen GitHub-Verzeichnis über `Add file → Upload files` ersetzen.
3. `BUNDLE_ID` unter `Settings → Secrets and variables → Actions → Variables`
   kontrollieren: `de.markus014.scanchris`.
4. Organisations-Secrets `TEAMID`, `GH_PAT`, `MATCH_PASSWORD`, `FASTLANE_KEY_ID`,
   `FASTLANE_ISSUER_ID`, `FASTLANE_KEY` müssen zugänglich sein. Keine Werte
   offenlegen oder in GitHub-Dateien hineinschreiben.
5. `Actions → Scanchris – Apple-Zugänge prüfen → Run workflow` starten.
6. Ist der Test grün: `Actions → Scanchris – TestFlight hochladen → Run workflow`.
   **Fastlane Match darf dafür ein eigenes App-Store-Provisioning-Profil
   für Scanchris erstellen**, benutzt aber die bestehenden Team-Zertifikate.
7. In App Store Connect → Scanchris → TestFlight den Upload/Build überprüfen und
   die interne Testgruppe konfigurieren. GitHub-Build erfolgreich ≠ Build schon
   für Tester freigegeben.

Optional für den türkisen Hinweis bei neuer TestFlight-Version:
- Repository-Variable `ASC_BETA_GROUP_ID` auf die ID der Testgruppe setzen.
- Workflow `Scanchris – verfügbare TestFlight-Version veröffentlichen` ausführen.
- GitHub Pages aus `gh-pages`/`(root)` veröffentlichen.

**Wichtig:** Das Paket enthält Quellcode, aber keine signierte IPA. Es wurde
nicht auf Xcode ausgeführt und nicht zu Apple hochgeladen. Den tatsächlichen
Build übernimmt GitHub Actions nach dem Hochladen.

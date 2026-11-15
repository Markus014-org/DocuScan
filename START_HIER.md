# DokuScan – Start in 8 Schritten

1. **Dieses ZIP entpacken** und **alle enthaltenen Dateien** in ein neues GitHub-Repository mit Branch `main` hochladen.
2. Unter **Actions → iOS Buildprüfung** zunächst kontrollieren, ob die App auf dem macOS-Runner für iOS kompiliert.
3. Im **Apple Developer Account** eine Bundle ID für DokuScan und in **App Store Connect** eine neue iOS-App anlegen.
4. Ein **Apple Distribution**-Zertifikat (`.p12`) und ein passendes App-Store-Provisioning-Profil (`.mobileprovision`) erstellen.
5. Einen **App Store Connect API Key** (`.p8`) erstellen und eine **TestFlight-Testgruppe** samt eigenem Testaccount einrichten.
6. Die Variablen `BUNDLE_ID`, `APPLE_TEAM_ID`, `ASC_BETA_GROUP_ID` und alle sieben in der `README.md` beschriebenen **Secrets** im GitHub-Repository hinterlegen.
7. Unter **Actions → TestFlight – Archivieren und hochladen** den Workflow manuell starten. Nach Apples Verarbeitung/ggf. Testfreigabe DokuScan über **TestFlight** auf dem iPhone installieren.
8. Unter **Actions → TestFlight – verfügbare Version veröffentlichen** den Versionsabgleich einmalig starten. **Settings → Pages** auf den danach entstandenen Branch `gh-pages` (Root) einstellen. Fortan wird alle 30 Minuten geprüft und beim Öffnen der App oben links türkis auf ein verfügbares Update hingewiesen.

**Die ausführliche Erklärung zu allen Apple-Zugangsdaten und Workflows steht in `README.md`.**

**Wichtig:** Eine Installation über TestFlight ist erst nach erfolgreichem Xcode-Build, Apple-Signierung und TestFlight-Verarbeitung möglich. Das hier gelieferte Archiv enthält die **Quelldateien**, keine bereits signierte `.ipa`.

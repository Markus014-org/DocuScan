import Foundation

struct TestFlightManifest: Decodable {
    let version: String
    let build: String
}

/// Zwei voneinander unabhängige Quellen:
/// 1. Optionales, von Apple bestätigtes TestFlight-Manifest (falls konfiguriert).
/// 2. Öffentliche erfolgreiche GitHub-Uploads. Dafür ist keine Beta-Gruppen-ID nötig.
/// Ein erfolgreicher Upload bedeutet noch NICHT, dass Apple den Build bereits
/// verarbeitet oder für Tester freigegeben hat.
enum UpdateChecker {
    struct CheckResult {
        let banner: String?
        let details: String
        var hasNewerBuild: Bool { banner != nil }
    }

    private struct GitHubRuns: Decodable {
        let workflow_runs: [GitHubRun]
    }
    private struct GitHubRun: Decodable {
        let run_number: Int
    }

    static func check() async -> CheckResult {
        let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let localBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let localNumber = Int(localBuild) ?? 0

        // Parallel prüfen: Ein nicht eingerichtetes GitHub Pages darf die
        // öffentliche GitHub-Actions-Abfrage nicht blockieren.
        async let manifest = loadConfirmedManifest()
        async let upload = loadLatestSuccessfulUpload()
        let (published, lastUpload) = await (manifest, upload)

        if let published {
            let order = published.version.compare(localVersion, options: .numeric)
            let newer = order == .orderedDescending ||
                (order == .orderedSame && published.build.compare(localBuild, options: .numeric) == .orderedDescending)
            if newer {
                return CheckResult(
                    banner: "Neue Version in TestFlight verfügbar (Build \(published.build))",
                    details: "Installiert: \(localVersion) (\(localBuild)). Von der TestFlight-Versionsdatei bestätigt: \(published.version) (\(published.build)). Öffne TestFlight zum Aktualisieren."
                )
            }
        }

        if let lastUpload, lastUpload > localNumber {
            return CheckResult(
                banner: "Neuer Build \(lastUpload) hochgeladen – TestFlight prüfen",
                details: "Installiert: \(localVersion) (\(localBuild)). Neuester erfolgreicher GitHub-TestFlight-Upload: Build \(lastUpload). Apple verarbeitet den Upload möglicherweise noch; prüfe TestFlight auf die neue Version."
            )
        }

        if let lastUpload {
            return CheckResult(
                banner: nil,
                details: "Installiert: \(localVersion) (\(localBuild)). Neuester erfolgreicher TestFlight-Upload auf GitHub: Build \(lastUpload). Es wurde kein neuerer Build gefunden."
            )
        }

        if let published {
            return CheckResult(
                banner: nil,
                details: "Installiert: \(localVersion) (\(localBuild)). Veröffentlichtes TestFlight-Manifest: \(published.version) (\(published.build)). GitHub-Uploads konnten nicht abgefragt werden."
            )
        }

        return CheckResult(
            banner: nil,
            details: "Installiert: \(localVersion) (\(localBuild)). Versionsprüfung nicht möglich. Bitte Internetzugriff prüfen und die Abfrage erneut versuchen."
        )
    }

    // Rückwärtskompatibler Aufruf für eventuelle weitere App-Stellen.
    static func isNewBuildAvailable() async -> Bool {
        await check().hasNewerBuild
    }

    private static func loadConfirmedManifest() async -> TestFlightManifest? {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "DokuScanUpdateURL") as? String,
              let url = URL(string: urlString), url.scheme == "https" else { return nil }
        return await fetch(TestFlightManifest.self, url: url)
    }

    private static func loadLatestSuccessfulUpload() async -> Int? {
        // Das öffentliche Repository benötigt keinen GitHub-Token auf dem iPhone.
        // CURRENT_PROJECT_VERSION wird beim TestFlight-Build auf
        // GITHUB_RUN_NUMBER gesetzt; genau das ist hier run_number.
        guard let url = URL(string:
            "https://api.github.com/repos/Markus014-org/DocuScan/actions/workflows/testflight.yml/runs?branch=main&status=success&per_page=5") else { return nil }
        guard let payload: GitHubRuns = await fetch(GitHubRuns.self, url: url) else { return nil }
        return payload.workflow_runs.map(\.run_number).max()
    }

    private static func fetch<T: Decodable>(_ type: T.Type, url: URL) async -> T? {
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 12
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(type, from: data)
        } catch {
            return nil
        }
    }
}

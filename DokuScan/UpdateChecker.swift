import Foundation

struct TestFlightManifest: Decodable {
    let version: String
    let build: String
}

enum UpdateChecker {
    static func isNewBuildAvailable() async -> Bool {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "DokuScanUpdateURL") as? String,
              !urlString.isEmpty,
              let url = URL(string: urlString), url.scheme == "https" else { return false }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            let latest = try JSONDecoder().decode(TestFlightManifest.self, from: data)
            let localVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            let localBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            let versionOrder = latest.version.compare(localVersion, options: .numeric)
            if versionOrder == .orderedDescending { return true }
            if versionOrder == .orderedSame {
                return latest.build.compare(localBuild, options: .numeric) == .orderedDescending
            }
            return false
        } catch { return false }
    }
}

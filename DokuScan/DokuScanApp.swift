import SwiftUI

@main
struct DokuScanApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(appModel)
                .tint(DokuTheme.orange)
                .preferredColorScheme(.light)
        }
    }
}

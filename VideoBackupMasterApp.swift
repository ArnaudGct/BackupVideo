import SwiftUI

@main
struct BackupVideoApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .navigationTitle("BackupVideo")
        }
        // Pour macOS, permet d'avoir une fenêtre resizable proprement avec des limites
        .windowResizability(.contentMinSize)
    }
}

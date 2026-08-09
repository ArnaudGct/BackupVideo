import SwiftUI

@main
struct VideoBackupMasterApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .navigationTitle("VideoBackupMaster")
        }
        // Pour macOS, permet d'avoir une fenêtre resizable proprement avec des limites
        .windowResizability(.contentMinSize)
    }
}

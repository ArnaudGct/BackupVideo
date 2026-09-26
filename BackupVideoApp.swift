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
        .commands {
            CommandGroup(after: .importExport) {
                Divider()
                Button("Afficher les logs") {
                    LoggerService.shared.openLogFile()
                }
                .keyboardShortcut("l", modifiers: [.command, .option])
            }
        }
    }
}

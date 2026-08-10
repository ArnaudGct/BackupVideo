import SwiftUI

struct DashboardView: View {
    @State private var viewModel = BackupViewModel()
    @State private var showLogs: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            ConfigurationZoneView(viewModel: viewModel)
                .frame(maxHeight: .infinity)
            
            Divider()
            
            // Ligne du bas : Exécution et Logs
            VStack(spacing: 16) {
                if showLogs {
                    LogConsoleView(logs: viewModel.progress.logs)
                        .frame(height: 150)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                VStack(spacing: 16) {
                    ExecutionZoneView(viewModel: viewModel)
                        .frame(maxWidth: 400)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            withAnimation {
                                showLogs.toggle()
                            }
                        }) {
                            Image(systemName: showLogs ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                            Text("Journal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button(action: {
                            LoggerService.shared.openLogFile()
                        }) {
                            Image(systemName: "doc.text")
                            Text("Ouvrir les Logs")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 1000, minHeight: 750)
        .onAppear {
            viewModel.restoreBookmarks()
        }
        .sheet(isPresented: $viewModel.showReportDialog) {
            if let report = viewModel.backupReport {
                BackupReportView(viewModel: viewModel, report: report)
            }
        }
        .alert("Erreur de sauvegarde", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}

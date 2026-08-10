import SwiftUI

struct DashboardView: View {
    @State private var viewModel = BackupViewModel()
    @State private var showLogs: Bool = false
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    
    var body: some View {
        HSplitView {
            // Colonne de gauche (Paramètres globaux)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Origine des vidéos")
                                .font(.title3)
                                .fontWeight(.bold)
                                
                            PathRowView(title: "", url: viewModel.config.sourceURL) {
                                viewModel.selectSourceURL()
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Paramètres par défaut", systemImage: "gearshape.fill")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Destinations & Nettoyage")
                                    .font(.headline)
                                
                                MultiPathSectionView(
                                    title: "Rendus Finaux",
                                    urls: viewModel.config.rendersDestinationURLs,
                                    isEnabled: $viewModel.enableRendersBackup,
                                    onAdd: { viewModel.addRendersDestinationURL() },
                                    onRemove: { index in viewModel.removeRendersDestinationURL(at: index) }
                                )
                                
                                MultiPathSectionView(
                                    title: "Projets Archivés",
                                    urls: viewModel.config.projectsDestinationURLs,
                                    isEnabled: $viewModel.enableProjectsBackup,
                                    onAdd: { viewModel.addProjectsDestinationURL() },
                                    onRemove: { index in viewModel.removeProjectsDestinationURL(at: index) }
                                ) {
                                    Button(action: { viewModel.showArchiveConfigPopover = true }) {
                                        Label("Nettoyage", systemImage: "trash")
                                    }
                                    .popover(isPresented: $viewModel.showArchiveConfigPopover, arrowEdge: .trailing) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Nettoyage de l'archive par défaut")
                                                .font(.headline)
                                            Toggle("Supprimer les Rushs", isOn: $viewModel.deleteRushsInArchive)
                                            Toggle("Supprimer les Rendus", isOn: $viewModel.deleteRendersInArchive)
                                        }
                                        .padding()
                                        .frame(width: 250)
                                    }
                                }
                                
                                MultiPathSectionView(
                                    title: "Rushs",
                                    urls: viewModel.config.rushDestinationURLs,
                                    isEnabled: $viewModel.enableRushBackup,
                                    onAdd: { viewModel.addRushDestinationURL() },
                                    onRemove: { index in viewModel.removeRushDestinationURL(at: index) }
                                )
                                
                                Divider()
                                
                                Text("Structure interne des projets")
                                    .font(.headline)
                                    .padding(.top, 4)
                                    
                                InternalStructureConfigView(
                                    namingFormat: $viewModel.namingFormat,
                                    rushFolderName: $viewModel.rushFolderName,
                                    renderFolderName: $viewModel.renderFolderName,
                                    renderSubfolderName: $viewModel.renderSubfolderName,
                                    useRenderSubfolder: $viewModel.useRenderSubfolder
                                )
                                
                                Divider()
                                
                                Toggle("Supprimer le projet source original après vérification", isOn: $viewModel.config.deleteOriginalProject)
                                    .tint(.red)
                                    .font(.headline)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                        }
                        }
                    }
                    .padding()
                }
                
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
                                Text("Logs")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 400, idealWidth: 450, maxWidth: 550)
            
            // Colonne de droite (Projets détectés)
            VStack(spacing: 0) {
                ProjectListView(viewModel: viewModel)
            }
            .frame(minWidth: 500, maxWidth: .infinity)
        }
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
        .sheet(isPresented: Binding(
            get: { !hasAcceptedDisclaimer },
            set: { _ in }
        )) {
            DisclaimerModalView()
                .interactiveDismissDisabled()
        }
    }
}

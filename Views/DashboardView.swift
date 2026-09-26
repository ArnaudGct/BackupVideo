import SwiftUI
import AppKit

struct DashboardView: View {
    @State private var viewModel = BackupViewModel()
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    @StateObject private var updateManager = UpdateManager(repoName: "ArnaudGct/VideoBackupMaster")
    
    var body: some View {
        HSplitView {
            // Colonne de gauche (Paramètres globaux)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Origine des vidéos")
                                    .font(.title3)
                                    .fontWeight(.bold)

                                Spacer()

                                Button { viewModel.addSourceURL() } label: {
                                    Label("Ajouter", systemImage: "folder.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }

                            SourcePathsView(
                                urls: viewModel.config.sourceURLs,
                                onRemove: { viewModel.removeSourceURL(at: $0) }
                            )
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Paramètres par défaut", systemImage: "gearshape.fill")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            GroupBox {
                            VStack(alignment: .leading, spacing: 16) {
                                InternalStructureConfigView(
                                    namingFormat: $viewModel.namingFormat,
                                    rushFolderName: $viewModel.rushFolderName,
                                    renderFolderName: $viewModel.renderFolderName,
                                    renderSubfolderName: $viewModel.renderSubfolderName,
                                    useRenderSubfolder: $viewModel.useRenderSubfolder,
                                    customCategories: $viewModel.customBackupCategories,
                                    showRendersBackup: $viewModel.showRendersBackup,
                                    showRushBackup: $viewModel.showRushBackup,
                                    rendersFolderIsBackup: $viewModel.rendersFolderIsBackup,
                                    rushFolderIsBackup: $viewModel.rushFolderIsBackup,
                                    rendersDestinationURLs: $viewModel.config.rendersDestinationURLs,
                                    rushDestinationURLs: $viewModel.config.rushDestinationURLs,
                                    projectsDestinationURLs: $viewModel.config.projectsDestinationURLs,
                                    enableRendersBackup: $viewModel.enableRendersBackup,
                                    enableRushBackup: $viewModel.enableRushBackup,
                                    enableProjectsBackup: $viewModel.enableProjectsBackup,
                                    deleteRushsInArchive: $viewModel.deleteRushsInArchive,
                                    deleteRendersInArchive: $viewModel.deleteRendersInArchive,
                                    onAddRendersDestination: { viewModel.addRendersDestinationURL() },
                                    onRemoveRendersDestination: { viewModel.removeRendersDestinationURL(at: $0) },
                                    onAddRushDestination: { viewModel.addRushDestinationURL() },
                                    onRemoveRushDestination: { viewModel.removeRushDestinationURL(at: $0) },
                                    onAddProjectsDestination: { viewModel.addProjectsDestinationURL() },
                                    onRemoveProjectsDestination: { viewModel.removeProjectsDestinationURL(at: $0) },
                                    onAddCustomDestination: { selectDestination(for: $0) },
                                    onRemoveCustomDestination: { id, index in
                                        guard let categoryIndex = viewModel.customBackupCategories.firstIndex(where: { $0.id == id }),
                                              viewModel.customBackupCategories[categoryIndex].destinationURLs.indices.contains(index) else { return }
                                        viewModel.customBackupCategories[categoryIndex].destinationURLs.remove(at: index)
                                    },
                                    onPersistConfiguration: { viewModel.persistBackupDestinations() }
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
                
                ExecutionZoneView(viewModel: viewModel)
                .padding()
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(minWidth: 360, idealWidth: 500, maxWidth: 1000)
            
            // Colonne de droite (Projets détectés)
            VStack(spacing: 0) {
                ProjectListView(viewModel: viewModel)
            }
            .frame(minWidth: 340, maxWidth: .infinity)
        }
        .frame(minWidth: 850, minHeight: 750)
        .onAppear {
            viewModel.restoreBookmarks()
            updateManager.checkForUpdates()
        }
        .sheet(isPresented: $updateManager.showUpdateSheet) {
            UpdateSheetView(updateManager: updateManager)
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

    private func selectDestination(for categoryID: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Sélectionner"
        guard panel.runModal() == .OK, let url = panel.url,
              let index = viewModel.customBackupCategories.firstIndex(where: { $0.id == categoryID }),
              !viewModel.customBackupCategories[index].destinationURLs.contains(url) else { return }
        viewModel.customBackupCategories[index].destinationURLs.append(url)
    }

}

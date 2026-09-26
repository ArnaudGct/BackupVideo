import SwiftUI

struct ProjectConfigModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var project: VideoProject
    let globalSettings: ProjectSettings
    @Bindable var viewModel: BackupViewModel
    
    @State private var useCustomSettings: Bool = false
    @State private var localSettings: ProjectSettings
    
    init(project: Binding<VideoProject>, globalSettings: ProjectSettings, viewModel: BackupViewModel) {
        self._project = project
        self.globalSettings = globalSettings
        self.viewModel = viewModel
        
        let initialSettings = project.wrappedValue.customSettings ?? globalSettings
        self._localSettings = State(initialValue: initialSettings)
        self._useCustomSettings = State(initialValue: project.wrappedValue.customSettings != nil)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // En-tête
            HStack {
                VStack(alignment: .leading) {
                    Text("Configuration de \(project.projectName)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Client: \(project.clientName)")
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Toggle("Personnaliser pour ce projet", isOn: $useCustomSettings)
                    .toggleStyle(.switch)
            }
            .padding()
            
            
            Divider()
            
            if useCustomSettings {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configurez l’organisation et les sauvegardes propres à ce projet.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                        InternalStructureConfigView(
                            namingFormat: .constant(viewModel.namingFormat),
                            rushFolderName: $localSettings.rushFolderName,
                            renderFolderName: $localSettings.renderFolderName,
                            renderSubfolderName: $localSettings.renderSubfolderName,
                            useRenderSubfolder: $localSettings.useRenderSubfolder,
                            customCategories: $localSettings.customBackupCategories,
                            showRendersBackup: $localSettings.showRendersBackup,
                            showRushBackup: $localSettings.showRushBackup,
                            rendersFolderIsBackup: $localSettings.rendersFolderIsBackup,
                            rushFolderIsBackup: $localSettings.rushFolderIsBackup,
                            rendersDestinationURLs: $localSettings.rendersDestinationURLs,
                            rushDestinationURLs: $localSettings.rushDestinationURLs,
                            projectsDestinationURLs: $localSettings.projectsDestinationURLs,
                            enableRendersBackup: $localSettings.enableRendersBackup,
                            enableRushBackup: $localSettings.enableRushBackup,
                            enableProjectsBackup: $localSettings.enableProjectsBackup,
                            deleteRushsInArchive: $localSettings.deleteRushsInArchive,
                            deleteRendersInArchive: $localSettings.deleteRendersInArchive,
                            onAddRendersDestination: { selectFolder(for: \.rendersDestinationURLs) },
                            onRemoveRendersDestination: { localSettings.rendersDestinationURLs.remove(at: $0) },
                            onAddRushDestination: { selectFolder(for: \.rushDestinationURLs) },
                            onRemoveRushDestination: { localSettings.rushDestinationURLs.remove(at: $0) },
                            onAddProjectsDestination: { selectFolder(for: \.projectsDestinationURLs) },
                            onRemoveProjectsDestination: { localSettings.projectsDestinationURLs.remove(at: $0) },
                            onAddCustomDestination: { selectFolder(forCustomCategory: $0) },
                            onRemoveCustomDestination: { id, index in
                                guard let categoryIndex = localSettings.customBackupCategories.firstIndex(where: { $0.id == id }),
                                      localSettings.customBackupCategories[categoryIndex].destinationURLs.indices.contains(index) else { return }
                                localSettings.customBackupCategories[categoryIndex].destinationURLs.remove(at: index)
                            },
                            onPersistConfiguration: { }
                        )

                    Spacer()
                }
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("Ce projet utilise les paramètres par défaut.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Activez la personnalisation en haut à droite pour modifier ses réglages.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Annuler") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Button("Sauvegarder") {
                    if useCustomSettings {
                        project.customSettings = localSettings
                    } else {
                        project.customSettings = nil
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
        }
        .frame(width: 600, height: 500)
    }
    
    private func selectFolder(for keyPath: WritableKeyPath<ProjectSettings, [URL]>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            BookmarkManager.shared.saveBookmark(for: url, key: url.path)
            localSettings[keyPath: keyPath].append(url)
        }
    }

    private func selectFolder(forCustomCategory id: UUID) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url,
           let index = localSettings.customBackupCategories.firstIndex(where: { $0.id == id }),
           !localSettings.customBackupCategories[index].destinationURLs.contains(url) {
            localSettings.customBackupCategories[index].destinationURLs.append(url)
        }
    }

}

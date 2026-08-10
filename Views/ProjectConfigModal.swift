import SwiftUI

struct ProjectConfigModal: View {
    @Environment(\.dismiss) var dismiss
    @Binding var project: VideoProject
    let globalSettings: ProjectSettings
    @Bindable var viewModel: BackupViewModel
    
    @State private var useCustomSettings: Bool = false
    @State private var localSettings: ProjectSettings
    @State private var selectedTab: Int = 0
    
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
                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text("Destinations & Nettoyage").tag(0)
                        Text("Dossiers").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    
                    if selectedTab == 0 {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                            Text("Personnalisez les emplacements de sauvegarde pour ce projet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            MultiPathSectionView(
                                title: "Rendus Finaux",
                                urls: localSettings.rendersDestinationURLs,
                                isEnabled: $localSettings.enableRendersBackup,
                                onAdd: { selectFolder(for: \.rendersDestinationURLs) },
                                onRemove: { idx in localSettings.rendersDestinationURLs.remove(at: idx) }
                            )
                            
                            MultiPathSectionView(
                                title: "Projets Archivés",
                                urls: localSettings.projectsDestinationURLs,
                                isEnabled: $localSettings.enableProjectsBackup,
                                onAdd: { selectFolder(for: \.projectsDestinationURLs) },
                                onRemove: { idx in localSettings.projectsDestinationURLs.remove(at: idx) }
                            ) {
                                Button(action: { }) { Label("Nettoyage", systemImage: "trash") }
                                    .hidden()
                                    .overlay(
                                        Menu {
                                            Toggle("Supprimer les Rushs", isOn: $localSettings.deleteRushsInArchive)
                                            Toggle("Supprimer les Rendus", isOn: $localSettings.deleteRendersInArchive)
                                        } label: {
                                            Label("Nettoyage", systemImage: "trash")
                                        }
                                        .menuIndicator(.hidden)
                                        .fixedSize()
                                    )
                            }
                            
                            MultiPathSectionView(
                                title: "Rushs",
                                urls: localSettings.rushDestinationURLs,
                                isEnabled: $localSettings.enableRushBackup,
                                onAdd: { selectFolder(for: \.rushDestinationURLs) },
                                onRemove: { idx in localSettings.rushDestinationURLs.remove(at: idx) }
                            )
                        }
                            .padding()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                        Text("Structure interne du projet")
                            .font(.headline)
                        
                        InternalStructureConfigView(
                            namingFormat: .constant(viewModel.namingFormat),
                            rushFolderName: $localSettings.rushFolderName,
                            renderFolderName: $localSettings.renderFolderName,
                            renderSubfolderName: $localSettings.renderSubfolderName,
                            useRenderSubfolder: $localSettings.useRenderSubfolder
                        )
                        
                        Spacer()
                    }
                        .padding()
                    }
                }
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
}

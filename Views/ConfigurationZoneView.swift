import SwiftUI

enum TemplateSelection {
    case root
    case rushs
    case rendus
    case subfolder
}

struct ConfigurationZoneView: View {
    @Bindable var viewModel: BackupViewModel
    @State private var selection: TemplateSelection = .root
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            
            // Colonne 1 : Origine & Architecture
            VStack(alignment: .leading, spacing: 16) {
                Text("1. Origine & Architecture")
                    .font(.title3)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    PathRowView(title: "Vidéos en cours", url: viewModel.config.sourceURL) {
                        viewModel.selectSourceURL()
                    }
                    
                    Divider()
                    
                    // Template Builder
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Structure interne des projets")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // Finder View (Top)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 0) {
                                    // Column 1
                                    FinderColumn {
                                        FinderClickableRow(
                                            title: rootTitle,
                                            icon: "folder.fill",
                                            isSelected: selection == .root,
                                            showChevron: true,
                                            action: { selection = .root }
                                        )
                                    }
                                    Divider()
                                    
                                    // Column 2
                                    FinderColumn {
                                        FinderClickableRow(
                                            title: viewModel.rushFolderName.isEmpty ? "Rushs" : viewModel.rushFolderName,
                                            icon: "folder.fill",
                                            isSelected: selection == .rushs,
                                            showChevron: false,
                                            action: { selection = .rushs }
                                        )
                                        FinderClickableRow(
                                            title: viewModel.renderFolderName.isEmpty ? "Rendus" : viewModel.renderFolderName,
                                            icon: "folder.fill",
                                            isSelected: selection == .rendus,
                                            showChevron: viewModel.useRenderSubfolder,
                                            action: { selection = .rendus }
                                        )
                                    }
                                    Divider()
                                    
                                    // Column 3
                                    if viewModel.useRenderSubfolder {
                                        FinderColumn {
                                            FinderClickableRow(
                                                title: viewModel.renderSubfolderName.isEmpty ? "Sous-dossier" : viewModel.renderSubfolderName,
                                                icon: "folder.fill",
                                                isSelected: selection == .subfolder,
                                                showChevron: false,
                                                action: { selection = .subfolder }
                                            )
                                        }
                                    } else {
                                        FinderColumn { EmptyView() }
                                    }
                                }
                            }
                            .frame(height: 120)
                            .background(Color(nsColor: .controlBackgroundColor))
                            
                            Divider()
                            
                            // Inspector (Bottom)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Inspecteur :")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    switch selection {
                                    case .root:
                                        Picker("", selection: $viewModel.namingFormat) {
                                            Text("Client_Projet").tag(ProjectNamingFormat.client_project)
                                            Text("Client - Projet").tag(ProjectNamingFormat.clientDashProject)
                                            Text("Projet_Client").tag(ProjectNamingFormat.project_client)
                                            Text("Projet - Client").tag(ProjectNamingFormat.projectDashClient)
                                        }
                                        .pickerStyle(.menu)
                                        .labelsHidden()
                                        
                                    case .rushs:
                                        TextField("Nom du dossier Rushs", text: $viewModel.rushFolderName)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: 200)
                                            
                                    case .rendus:
                                        TextField("Nom du dossier Rendus", text: $viewModel.renderFolderName)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: 200)
                                        
                                        Toggle("Sous-dossier", isOn: $viewModel.useRenderSubfolder)
                                            .onChange(of: viewModel.useRenderSubfolder) { _, newValue in
                                                if !newValue && selection == .subfolder {
                                                    selection = .rendus
                                                }
                                            }
                                            
                                    case .subfolder:
                                        TextField("Nom du sous-dossier", text: $viewModel.renderSubfolderName)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(maxWidth: 200)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .windowBackgroundColor))
                        }
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                    }
                    
                    Divider()
                    
                    // Projects detected list
                    ProjectListView(viewModel: viewModel)
                        .frame(maxHeight: .infinity)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            
            // Colonne 2 : Destinations & Nettoyage
            VStack(alignment: .leading, spacing: 16) {
                Text("2. Destinations & Nettoyage")
                    .font(.title3)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 20) {
                    PathRowView(title: "Rendus Finaux", url: viewModel.config.rendersDestinationURL, isEnabled: $viewModel.enableRendersBackup) {
                        viewModel.selectRendersDestinationURL()
                    }
                    
                    PathRowView(title: "Projets Archivés", url: viewModel.config.projectsDestinationURL, isEnabled: $viewModel.enableProjectsBackup, action: {
                        viewModel.selectProjectsDestinationURL()
                    }, trailingContent: {
                        Button(action: { viewModel.showArchiveConfigPopover = true }) {
                            Label("Configurer", systemImage: "gear")
                        }
                        .popover(isPresented: $viewModel.showArchiveConfigPopover, arrowEdge: .trailing) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Nettoyage de l'archive")
                                    .font(.headline)
                                Text("Sélectionnez les dossiers à supprimer dans la copie archivée du projet.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Toggle("Supprimer les Rushs", isOn: $viewModel.deleteRushsInArchive)
                                Toggle("Supprimer les Rendus", isOn: $viewModel.deleteRendersInArchive)
                            }
                            .padding()
                            .frame(width: 250)
                        }
                    })
                    
                    PathRowView(title: "Rushs", url: viewModel.config.rushDestinationURL, isEnabled: $viewModel.enableRushBackup) {
                        viewModel.selectRushDestinationURL()
                    }
                    
                    Divider()
                    
                    Toggle("Supprimer le projet source original après vérification", isOn: $viewModel.config.deleteOriginalProject)
                        .tint(.red)
                        .font(.headline)
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                
                Spacer() // Push everything to the top
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    var rootTitle: String {
        switch viewModel.namingFormat {
        case .client_project: return "Client_Projet"
        case .clientDashProject: return "Client - Projet"
        case .project_client: return "Projet_Client"
        case .projectDashClient: return "Projet - Client"
        }
    }
}

// ... remaining views (FinderColumn, FinderClickableRow, PathRowView) ...
struct FinderColumn<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            content
            Spacer()
        }
        .frame(width: 150)
        .padding(.vertical, 4)
    }
}

struct FinderClickableRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let showChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(6)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

struct PathRowView<TrailingContent: View>: View {
    let title: String
    let url: URL?
    var isEnabled: Binding<Bool>?
    let action: () -> Void
    let trailingContent: TrailingContent
    
    init(title: String, url: URL?, isEnabled: Binding<Bool>? = nil, action: @escaping () -> Void, @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }) {
        self.title = title
        self.url = url
        self.isEnabled = isEnabled
        self.action = action
        self.trailingContent = trailingContent()
    }
    
    var body: some View {
        HStack {
            if let isEnabledBinding = isEnabled {
                Toggle("", isOn: isEnabledBinding)
                    .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor((isEnabled?.wrappedValue ?? true) ? .primary : .secondary)
                
                if (isEnabled?.wrappedValue ?? true) {
                    Text(url?.path ?? "Aucun dossier sélectionné")
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(url == nil ? .red : .primary)
                } else {
                    Text("Désactivé")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer(minLength: 20)
            
            trailingContent
                .disabled(!(isEnabled?.wrappedValue ?? true))
            
            Button(action: action) {
                Image(systemName: "folder.badge.plus")
                Text("Parcourir")
            }
            .buttonStyle(.bordered)
            .disabled(!(isEnabled?.wrappedValue ?? true))
        }
        .opacity((isEnabled?.wrappedValue ?? true) ? 1.0 : 0.6)
    }
}

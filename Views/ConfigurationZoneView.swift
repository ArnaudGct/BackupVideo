import SwiftUI

enum TemplateSelection {
    case root
    case rushs
    case rendus
    case subfolder
}

struct InternalStructureConfigView: View {
    @Binding var namingFormat: ProjectNamingFormat
    @Binding var rushFolderName: String
    @Binding var renderFolderName: String
    @Binding var renderSubfolderName: String
    @Binding var useRenderSubfolder: Bool
    @State private var selection: TemplateSelection = .root
    
    var body: some View {
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
                            title: rushFolderName.isEmpty ? "Rushs" : rushFolderName,
                            icon: "folder.fill",
                            isSelected: selection == .rushs,
                            showChevron: false,
                            action: { selection = .rushs }
                        )
                        FinderClickableRow(
                            title: renderFolderName.isEmpty ? "Rendus" : renderFolderName,
                            icon: "folder.fill",
                            isSelected: selection == .rendus,
                            showChevron: useRenderSubfolder,
                            action: { selection = .rendus }
                        )
                    }
                    Divider()
                    
                    // Column 3
                    if useRenderSubfolder && (selection == .rendus || selection == .subfolder) {
                        FinderColumn {
                            FinderClickableRow(
                                title: renderSubfolderName.isEmpty ? "Sous-dossier" : renderSubfolderName,
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
            .background(Color(nsColor: .textBackgroundColor))
            
            Divider()
            
            // Inspector (Bottom)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Inspecteur :")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    switch selection {
                    case .root:
                        Picker("", selection: $namingFormat) {
                            Text("Client_Projet").tag(ProjectNamingFormat.client_project)
                            Text("Client - Projet").tag(ProjectNamingFormat.clientDashProject)
                            Text("Projet_Client").tag(ProjectNamingFormat.project_client)
                            Text("Projet - Client").tag(ProjectNamingFormat.projectDashClient)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        
                    case .rushs:
                        TextField("Nom du dossier Rushs", text: $rushFolderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                            
                    case .rendus:
                        TextField("Nom du dossier Rendus", text: $renderFolderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                        
                        Toggle("Sous-dossier", isOn: $useRenderSubfolder)
                            .onChange(of: useRenderSubfolder) { _, newValue in
                                if !newValue && selection == .subfolder {
                                    selection = .rendus
                                }
                            }
                        
                    case .subfolder:
                        TextField("Nom du sous-dossier", text: $renderSubfolderName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                    }
                }
                
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
    
    var helpText: String {
        switch selection {
        case .root:
            return "Dossier racine du projet. Choisissez le format de nom attendu pour que l'application détecte vos projets."
        case .rushs:
            return "C'est ici que vous stockez vos médias bruts. Assurez-vous que le nom correspond exactement à celui utilisé dans vos projets."
        case .rendus:
            return "Dossier destiné aux exports finaux. Renseignez son nom exact pour que l'application puisse les identifier."
        case .subfolder:
            return "Si vos rendus sont placés dans un sous-dossier spécifique (ex: 'Def', 'Exports'), précisez-le ici."
        }
    }
    
    var rootTitle: String {
        switch namingFormat {
        case .client_project: return "Client_Projet"
        case .clientDashProject: return "Client - Projet"
        case .project_client: return "Projet_Client"
        case .projectDashClient: return "Projet - Client"
        }
    }
}

// ... remaining views (FinderColumn, FinderClickableRow, PathRowView, MultiPathSectionView) ...
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

// Composant pour afficher et gérer plusieurs chemins de destination
struct MultiPathSectionView<TrailingContent: View>: View {
    let title: String
    let urls: [URL]
    var isEnabled: Binding<Bool>
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    let trailingContent: TrailingContent
    
    init(title: String, urls: [URL], isEnabled: Binding<Bool>, onAdd: @escaping () -> Void, onRemove: @escaping (Int) -> Void, @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }) {
        self.title = title
        self.urls = urls
        self.isEnabled = isEnabled
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.trailingContent = trailingContent()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: isEnabled)
                    .labelsHidden()
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isEnabled.wrappedValue ? .primary : .secondary)
                
                Spacer()
                
                trailingContent
                    .disabled(!isEnabled.wrappedValue)
                
                Button(action: onAdd) {
                    Image(systemName: "folder.badge.plus")
                    Text("Ajouter")
                }
                .buttonStyle(.bordered)
                .disabled(!isEnabled.wrappedValue)
            }
            
            if isEnabled.wrappedValue {
                if urls.isEmpty {
                    Text("Aucun dossier sélectionné")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.leading, 32)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(urls.indices, id: \.self) { index in
                            HStack {
                                Text(urls[index].path)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    onRemove(index)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 32)
                        }
                    }
                }
            } else {
                Text("Désactivé")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.leading, 32)
            }
        }
        .opacity(isEnabled.wrappedValue ? 1.0 : 0.6)
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
                if !title.isEmpty {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor((isEnabled?.wrappedValue ?? true) ? .primary : .secondary)
                }
                
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

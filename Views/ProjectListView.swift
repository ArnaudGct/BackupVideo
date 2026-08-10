import SwiftUI

struct ProjectListView: View {
    @Bindable var viewModel: BackupViewModel
    @State private var projectToConfigIndex: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            HStack {
                Text("Projets détectés (\(viewModel.projects.count))")
                    .font(.headline)
                
                Spacer()
                
                Button("Tout cocher") {
                    for i in viewModel.projects.indices {
                        viewModel.projects[i].isSelected = true
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 4)
                
                Text("|")
                    .foregroundColor(.secondary)
                
                Button("Tout décocher") {
                    for i in viewModel.projects.indices {
                        viewModel.projects[i].isSelected = false
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.leading, 4)
                .padding(.trailing, 16)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            if viewModel.projects.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 8)
                    Text("Aucun projet trouvé dans le dossier source.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            } else {
                List($viewModel.projects) { $project in
                    HStack {
                        Toggle("", isOn: $project.isSelected)
                            .labelsHidden()
                        
                        VStack(alignment: .leading) {
                            Text(project.projectName)
                                .font(.headline)
                            Text("Client: \(project.clientName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(project.sizeFormatted)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .windowBackgroundColor))
                            .cornerRadius(4)
                        
                        Button(action: {
                            if let index = viewModel.projects.firstIndex(where: { $0.id == project.id }) {
                                projectToConfigIndex = index
                            }
                        }) {
                            Image(systemName: "gearshape")
                            Text("Configurer")
                        }
                        .buttonStyle(.bordered)
                        .tint((project.customSettings != nil) ? .blue : .primary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .sheet(isPresented: Binding(
                    get: { projectToConfigIndex != nil },
                    set: { if !$0 { projectToConfigIndex = nil } }
                )) {
                    if let index = projectToConfigIndex, viewModel.projects.indices.contains(index) {
                        ProjectConfigModal(
                            project: $viewModel.projects[index],
                            globalSettings: viewModel.globalSettings,
                            viewModel: viewModel
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

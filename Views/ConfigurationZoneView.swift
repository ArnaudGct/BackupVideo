import SwiftUI

private struct FolderPath: Identifiable, Hashable {
    let components: [String]
    var id: String { components.joined(separator: "\u{1F}") }
    var name: String { components.last ?? "" }
}

private struct FolderConfigurationSnapshot {
    let namingFormat: ProjectNamingFormat
    let selectedPath: [String]
    let rushFolderName: String
    let renderFolderName: String
    let renderSubfolderName: String
    let useRenderSubfolder: Bool
    let customCategories: [CustomBackupCategory]
    let showRendersBackup: Bool
    let showRushBackup: Bool
    let rendersFolderIsBackup: Bool
    let rushFolderIsBackup: Bool
    let rendersDestinationURLs: [URL]
    let rushDestinationURLs: [URL]
    let projectsDestinationURLs: [URL]
    let enableRendersBackup: Bool
    let enableRushBackup: Bool
    let enableProjectsBackup: Bool
    let deleteRushsInArchive: Bool
    let deleteRendersInArchive: Bool
}

private struct ArchiveExclusionOption: Identifiable {
    let id: String
    let folderPath: String
    let isExcluded: Binding<Bool>
}

struct InternalStructureConfigView: View {
    @Binding var namingFormat: ProjectNamingFormat
    @Binding var rushFolderName: String
    @Binding var renderFolderName: String
    @Binding var renderSubfolderName: String
    @Binding var useRenderSubfolder: Bool
    @Binding var customCategories: [CustomBackupCategory]
    @Binding var showRendersBackup: Bool
    @Binding var showRushBackup: Bool
    @Binding var rendersFolderIsBackup: Bool
    @Binding var rushFolderIsBackup: Bool
    @Binding var rendersDestinationURLs: [URL]
    @Binding var rushDestinationURLs: [URL]
    @Binding var projectsDestinationURLs: [URL]
    @Binding var enableRendersBackup: Bool
    @Binding var enableRushBackup: Bool
    @Binding var enableProjectsBackup: Bool
    @Binding var deleteRushsInArchive: Bool
    @Binding var deleteRendersInArchive: Bool
    let onAddRendersDestination: () -> Void
    let onRemoveRendersDestination: (Int) -> Void
    let onAddRushDestination: () -> Void
    let onRemoveRushDestination: (Int) -> Void
    let onAddProjectsDestination: () -> Void
    let onRemoveProjectsDestination: (Int) -> Void
    let onAddCustomDestination: (UUID) -> Void
    let onRemoveCustomDestination: (UUID, Int) -> Void
    let onPersistConfiguration: () -> Void
    @State private var selectedPath: [String] = []
    @State private var showFolderConfiguration = false
    @State private var showDeleteConfirmation = false
    @State private var configurationSnapshot: FolderConfigurationSnapshot?

    private var rushPath: [String] { components(from: rushFolderName) }
    private var renderPath: [String] {
        components(from: renderFolderName) + (useRenderSubfolder ? components(from: renderSubfolderName) : [])
    }
    private var leafPaths: [[String]] {
        (showRushBackup ? [rushPath] : [])
            + (showRendersBackup ? [renderPath] : [])
            + customCategories.map(\.pathComponents)
    }
    private var backupPaths: [[String]] {
        (showRushBackup && rushFolderIsBackup ? [rushPath] : [])
            + (showRendersBackup && rendersFolderIsBackup ? [renderPath] : [])
            + customCategories.filter(\.isBackup).map(\.pathComponents)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { addChildCategory() } label: {
                    Label(selectedPath.isEmpty ? "Nouveau dossier" : "Nouveau sous-dossier", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)

                Button { beginFolderConfiguration() } label: {
                    Label("Configurer", systemImage: "gearshape")
                }
                .buttonStyle(.borderless)

                Spacer()

                if isDeletable(selectedPath) {
                    Button(role: .destructive) { requestDeletion() } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .help("Supprimer ce dossier")
                }
            }
            .frame(height: 28)
            .padding(.horizontal, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    FinderColumn {
                        FinderClickableRow(
                            title: rootTitle,
                            icon: "externaldrive.fill",
                            isSelected: selectedPath.isEmpty,
                            showChevron: true,
                            action: { selectedPath = [] }
                        )
                    }
                    Divider()

                    pathColumn(prefix: [])

                    if !selectedPath.isEmpty {
                        ForEach(1...selectedPath.count, id: \.self) { depth in
                            let prefix = Array(selectedPath.prefix(depth))
                            if !children(of: prefix).isEmpty {
                                Divider()
                                pathColumn(prefix: prefix)
                            }
                        }
                    }
                }
            }
            .frame(height: 120)
            .background(Color(nsColor: .textBackgroundColor))

        }
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
        .sheet(isPresented: $showFolderConfiguration) {
            FolderConfigurationSheet(
                isRoot: selectedPath.isEmpty,
                path: selectedPath.isEmpty ? rootTitle : ([rootTitle] + selectedPath).joined(separator: " › "),
                namingFormat: $namingFormat,
                folderName: selectedFolderName,
                isBackup: selectedFolderIsBackup,
                isEnabled: selectedFolderIsEnabled,
                destinationURLs: selectedDestinationURLs,
                archiveExclusionOptions: archiveExclusionOptions,
                onAddDestination: addSelectedDestination,
                onRemoveDestination: removeSelectedDestination,
                onCancel: cancelFolderConfiguration,
                onSave: saveFolderConfiguration
            )
        }
        .alert("Supprimer cette sauvegarde ?", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) { deleteSelection() }
        } message: {
            Text("Le dossier et ses destinations configurées seront retirés de BackupVideo. Aucun fichier présent sur vos disques ne sera supprimé.")
        }
    }

    @ViewBuilder
    private func pathColumn(prefix: [String]) -> some View {
        FinderColumn {
            ForEach(children(of: prefix)) { child in
                FinderClickableRow(
                    title: child.name,
                    icon: backupPaths.contains(child.components) ? "externaldrive.fill" : "folder.fill",
                    isSelected: selectedPath == child.components,
                    showChevron: !children(of: child.components).isEmpty,
                    action: { selectedPath = child.components }
                )
            }
        }
    }

    private func children(of prefix: [String]) -> [FolderPath] {
        var paths = Set<FolderPath>()
        for leaf in leafPaths where leaf.count > prefix.count && Array(leaf.prefix(prefix.count)) == prefix {
            paths.insert(FolderPath(components: Array(leaf.prefix(prefix.count + 1))))
        }
        return paths.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func components(from value: String) -> [String] {
        value.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func isDeletable(_ path: [String]) -> Bool {
        guard !path.isEmpty else { return false }
        let isBuiltInFolder = (showRushBackup && path == rushPath)
            || (showRendersBackup && path == renderPath)
        let containsCustomFolder = customCategories.contains { $0.pathComponents.starts(with: path) }
        return isBuiltInFolder || containsCustomFolder
    }

    private func renameSelectedFolder(to rawName: String) {
        let cleanName = rawName.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !selectedPath.isEmpty else { return }
        let oldPrefix = selectedPath
        var newPrefix = selectedPath
        newPrefix[newPrefix.count - 1] = cleanName

        func replacingPrefix(in path: [String]) -> [String] {
            guard path.starts(with: oldPrefix) else { return path }
            return newPrefix + path.dropFirst(oldPrefix.count)
        }

        let updatedRush = replacingPrefix(in: rushPath)
        if updatedRush != rushPath { rushFolderName = updatedRush.joined(separator: "/") }

        let updatedRender = replacingPrefix(in: renderPath)
        if updatedRender != renderPath {
            let renderRootDepth = max(1, components(from: renderFolderName).count)
            renderFolderName = updatedRender.prefix(renderRootDepth).joined(separator: "/")
            let remaining = Array(updatedRender.dropFirst(renderRootDepth))
            useRenderSubfolder = !remaining.isEmpty
            renderSubfolderName = remaining.joined(separator: "/")
        }

        for index in customCategories.indices {
            customCategories[index].pathComponents = replacingPrefix(in: customCategories[index].pathComponents)
            if customCategories[index].pathComponents == newPrefix {
                customCategories[index].name = cleanName
            }
        }
        selectedPath = newPrefix
    }

    private func uniqueChildName() -> String {
        var name = "Nouveau dossier"
        var suffix = 2
        while leafPaths.contains(selectedPath + [name]) {
            name = "Nouveau dossier \(suffix)"
            suffix += 1
        }
        return name
    }

    private func addChildCategory() {
        let name = uniqueChildName()
        let path = selectedPath + [name]
        customCategories.append(CustomBackupCategory(name: name, pathComponents: path, isBackup: false))
        selectedPath = path
    }

    private func deleteSelection() {
        if showRushBackup, selectedPath == rushPath {
            preserveParentFolder(of: rushPath)
            showRushBackup = false
            rushFolderIsBackup = false
        }

        if showRendersBackup, selectedPath == renderPath {
            preserveParentFolder(of: renderPath)
            showRendersBackup = false
            rendersFolderIsBackup = false
        }

        customCategories.removeAll { $0.pathComponents.starts(with: selectedPath) }
        selectedPath = Array(selectedPath.dropLast())
    }

    private func requestDeletion() {
        if backupPaths.contains(where: { $0.starts(with: selectedPath) }) {
            showDeleteConfirmation = true
        } else {
            deleteSelection()
        }
    }

    private func preserveParentFolder(of path: [String]) {
        let parent = Array(path.dropLast())
        guard !parent.isEmpty,
              !customCategories.contains(where: { $0.pathComponents == parent }) else { return }
        customCategories.append(CustomBackupCategory(name: parent.last ?? "Dossier", pathComponents: parent, isBackup: false))
    }

    private var selectedFolderIsBackup: Binding<Bool> {
        Binding(
            get: {
                if showRushBackup, selectedPath == rushPath { return rushFolderIsBackup }
                if showRendersBackup, selectedPath == renderPath { return rendersFolderIsBackup }
                return customCategories.first(where: { $0.pathComponents == selectedPath })?.isBackup ?? false
            },
            set: { newValue in
                if showRushBackup, selectedPath == rushPath {
                    rushFolderIsBackup = newValue
                    return
                }
                if showRendersBackup, selectedPath == renderPath {
                    rendersFolderIsBackup = newValue
                    return
                }
                if let index = customCategories.firstIndex(where: { $0.pathComponents == selectedPath }) {
                    customCategories[index].isBackup = newValue
                } else if !selectedPath.isEmpty {
                    customCategories.append(CustomBackupCategory(
                        name: selectedPath.last ?? "Dossier",
                        pathComponents: selectedPath,
                        isBackup: newValue
                    ))
                }
            }
        )
    }

    private var selectedFolderName: Binding<String> {
        Binding(
            get: { selectedPath.last ?? rootTitle },
            set: { renameSelectedFolder(to: $0) }
        )
    }

    private var selectedFolderIsEnabled: Binding<Bool> {
        Binding(
            get: {
                if selectedPath.isEmpty { return enableProjectsBackup }
                if showRushBackup, selectedPath == rushPath { return enableRushBackup }
                if showRendersBackup, selectedPath == renderPath { return enableRendersBackup }
                return selectedCustomCategory?.isEnabled ?? true
            },
            set: { newValue in
                if selectedPath.isEmpty { enableProjectsBackup = newValue; return }
                if showRushBackup, selectedPath == rushPath { enableRushBackup = newValue; return }
                if showRendersBackup, selectedPath == renderPath { enableRendersBackup = newValue; return }
                guard let index = selectedCustomCategoryIndex else { return }
                customCategories[index].isEnabled = newValue
            }
        )
    }

    private var selectedDestinationURLs: Binding<[URL]> {
        Binding(
            get: {
                if selectedPath.isEmpty { return projectsDestinationURLs }
                if showRushBackup, selectedPath == rushPath { return rushDestinationURLs }
                if showRendersBackup, selectedPath == renderPath { return rendersDestinationURLs }
                return selectedCustomCategory?.destinationURLs ?? []
            },
            set: { newValue in
                if selectedPath.isEmpty { projectsDestinationURLs = newValue; return }
                if showRushBackup, selectedPath == rushPath { rushDestinationURLs = newValue; return }
                if showRendersBackup, selectedPath == renderPath { rendersDestinationURLs = newValue; return }
                guard let index = selectedCustomCategoryIndex else { return }
                customCategories[index].destinationURLs = newValue
            }
        )
    }

    private var selectedCustomCategoryIndex: Int? {
        customCategories.firstIndex { $0.pathComponents == selectedPath }
    }

    private var selectedCustomCategory: CustomBackupCategory? {
        guard let index = selectedCustomCategoryIndex else { return nil }
        return customCategories[index]
    }

    private var archiveExclusionOptions: [ArchiveExclusionOption] {
        var options: [ArchiveExclusionOption] = []

        if showRushBackup && rushFolderIsBackup {
            options.append(ArchiveExclusionOption(
                id: "rushs",
                folderPath: rushPath.joined(separator: " / "),
                isExcluded: $deleteRushsInArchive
            ))
        }

        if showRendersBackup && rendersFolderIsBackup {
            options.append(ArchiveExclusionOption(
                id: "renders",
                folderPath: renderPath.joined(separator: " / "),
                isExcluded: $deleteRendersInArchive
            ))
        }

        for category in customCategories where category.isBackup {
            let id = category.id
            options.append(ArchiveExclusionOption(
                id: id.uuidString,
                folderPath: category.pathComponents.joined(separator: " / "),
                isExcluded: Binding(
                    get: { customCategories.first(where: { $0.id == id })?.excludeFromArchive ?? false },
                    set: { value in
                        guard let index = customCategories.firstIndex(where: { $0.id == id }) else { return }
                        customCategories[index].excludeFromArchive = value
                    }
                )
            ))
        }
        return options
    }

    private func addSelectedDestination() {
        if selectedPath.isEmpty { onAddProjectsDestination(); return }
        if showRushBackup, selectedPath == rushPath { onAddRushDestination(); return }
        if showRendersBackup, selectedPath == renderPath { onAddRendersDestination(); return }
        guard let id = selectedCustomCategory?.id else { return }
        onAddCustomDestination(id)
    }

    private func removeSelectedDestination(at index: Int) {
        if selectedPath.isEmpty { onRemoveProjectsDestination(index); return }
        if showRushBackup, selectedPath == rushPath { onRemoveRushDestination(index); return }
        if showRendersBackup, selectedPath == renderPath { onRemoveRendersDestination(index); return }
        guard let id = selectedCustomCategory?.id else { return }
        onRemoveCustomDestination(id, index)
    }

    private func beginFolderConfiguration() {
        configurationSnapshot = FolderConfigurationSnapshot(
            namingFormat: namingFormat,
            selectedPath: selectedPath,
            rushFolderName: rushFolderName,
            renderFolderName: renderFolderName,
            renderSubfolderName: renderSubfolderName,
            useRenderSubfolder: useRenderSubfolder,
            customCategories: customCategories,
            showRendersBackup: showRendersBackup,
            showRushBackup: showRushBackup,
            rendersFolderIsBackup: rendersFolderIsBackup,
            rushFolderIsBackup: rushFolderIsBackup,
            rendersDestinationURLs: rendersDestinationURLs,
            rushDestinationURLs: rushDestinationURLs,
            projectsDestinationURLs: projectsDestinationURLs,
            enableRendersBackup: enableRendersBackup,
            enableRushBackup: enableRushBackup,
            enableProjectsBackup: enableProjectsBackup,
            deleteRushsInArchive: deleteRushsInArchive,
            deleteRendersInArchive: deleteRendersInArchive
        )
        showFolderConfiguration = true
    }

    private func cancelFolderConfiguration() {
        guard let snapshot = configurationSnapshot else {
            showFolderConfiguration = false
            return
        }
        namingFormat = snapshot.namingFormat
        selectedPath = snapshot.selectedPath
        rushFolderName = snapshot.rushFolderName
        renderFolderName = snapshot.renderFolderName
        renderSubfolderName = snapshot.renderSubfolderName
        useRenderSubfolder = snapshot.useRenderSubfolder
        customCategories = snapshot.customCategories
        showRendersBackup = snapshot.showRendersBackup
        showRushBackup = snapshot.showRushBackup
        rendersFolderIsBackup = snapshot.rendersFolderIsBackup
        rushFolderIsBackup = snapshot.rushFolderIsBackup
        rendersDestinationURLs = snapshot.rendersDestinationURLs
        rushDestinationURLs = snapshot.rushDestinationURLs
        projectsDestinationURLs = snapshot.projectsDestinationURLs
        enableRendersBackup = snapshot.enableRendersBackup
        enableRushBackup = snapshot.enableRushBackup
        enableProjectsBackup = snapshot.enableProjectsBackup
        deleteRushsInArchive = snapshot.deleteRushsInArchive
        deleteRendersInArchive = snapshot.deleteRendersInArchive
        onPersistConfiguration()
        configurationSnapshot = nil
        showFolderConfiguration = false
    }

    private func saveFolderConfiguration() {
        onPersistConfiguration()
        configurationSnapshot = nil
        showFolderConfiguration = false
    }

    private var rootTitle: String { namingFormat.rawValue }
}

private struct FolderConfigurationSheet: View {
    let isRoot: Bool
    let path: String
    @Binding var namingFormat: ProjectNamingFormat
    @Binding var folderName: String
    @Binding var isBackup: Bool
    @Binding var isEnabled: Bool
    @Binding var destinationURLs: [URL]
    let archiveExclusionOptions: [ArchiveExclusionOption]
    let onAddDestination: () -> Void
    let onRemoveDestination: (Int) -> Void
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: isRoot ? "externaldrive.fill" : (isBackup ? "externaldrive.fill" : "folder.fill"))
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(isRoot ? "Configurer le dossier projet" : "Configurer le dossier")
                        .font(.title3.weight(.semibold))
                    Text(path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if isRoot {
                        LabeledContent("Format du dossier projet") {
                            Picker("Format du dossier projet", selection: $namingFormat) {
                                ForEach(ProjectNamingFormat.allCases) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 180)
                        }

                        Text("Ce format est utilisé pour reconnaître les dossiers client et projet pendant le scan.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        backupConfiguration

                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Nettoyage de l’archive")
                                .font(.headline)
                            ForEach(archiveExclusionOptions) { option in
                                Toggle("Exclure le dossier de sauvegarde « \(option.folderPath) »", isOn: option.isExcluded)
                            }
                            if archiveExclusionOptions.isEmpty {
                                Text("Aucun dossier de sauvegarde à exclure.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text("Ces options réduisent l’archive complète sans modifier les dossiers sources.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Nom du dossier")
                                .font(.subheadline.weight(.semibold))
                            TextField("Nom du dossier", text: $folderName)
                                .textFieldStyle(.roundedBorder)
                        }

                        LabeledContent("Type du dossier") {
                            Picker("Type du dossier", selection: $isBackup) {
                                Text("Dossier").tag(false)
                                Text("Sauvegarde").tag(true)
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 150)
                        }

                        if isBackup {
                            Divider()
                            backupConfiguration
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("Annuler", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 500, height: isRoot ? 600 : (isBackup ? 560 : 340))
    }

    @ViewBuilder
    private var backupConfiguration: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destinations")
                        .font(.headline)
                    Text("Disques ou dossiers qui recevront cette sauvegarde.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("Activée", isOn: $isEnabled)
                    .toggleStyle(.switch)
            }

            VStack(spacing: 8) {
                if destinationURLs.isEmpty {
                    Text("Aucune destination sélectionnée")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    ForEach(destinationURLs.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(.accentColor)
                            Text(destinationURLs[index].path)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button { onRemoveDestination(index) } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button(action: onAddDestination) {
                    Label("Ajouter une destination", systemImage: "externaldrive.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.accentColor)
            }
        }
    }
}

struct FinderColumn<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        VStack(spacing: 0) {
            content
            Spacer()
        }
        .frame(width: 190)
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

struct SourcePathsView: View {
    let urls: [URL]
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(urls.indices, id: \.self) { index in
                HStack {
                    Text(urls[index].path)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 12)
                    Button { onRemove(index) } label: {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            if urls.isEmpty {
                Text("Aucun dossier sélectionné")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
    }
}

struct MultiPathSectionView<TrailingContent: View>: View {
    private let fixedTitle: String?
    private var editableTitle: Binding<String>?
    private let sourcePath: String?
    let urls: [URL]
    var isEnabled: Binding<Bool>
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    let trailingContent: TrailingContent

    init(title: String, sourcePath: String? = nil, urls: [URL], isEnabled: Binding<Bool>, onAdd: @escaping () -> Void, onRemove: @escaping (Int) -> Void, @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }) {
        self.fixedTitle = title
        self.editableTitle = nil
        self.sourcePath = sourcePath
        self.urls = urls
        self.isEnabled = isEnabled
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.trailingContent = trailingContent()
    }

    init(title: Binding<String>, sourcePath: String? = nil, urls: [URL], isEnabled: Binding<Bool>, onAdd: @escaping () -> Void, onRemove: @escaping (Int) -> Void, @ViewBuilder trailingContent: () -> TrailingContent = { EmptyView() }) {
        self.fixedTitle = nil
        self.editableTitle = title
        self.sourcePath = sourcePath
        self.urls = urls
        self.isEnabled = isEnabled
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.trailingContent = trailingContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: isEnabled).labelsHidden()

                VStack(alignment: .leading, spacing: 2) {
                    if let editableTitle {
                        TextField("Nom", text: editableTitle)
                            .textFieldStyle(.plain)
                            .font(.subheadline)
                            .frame(minWidth: 90, idealWidth: 130, maxWidth: 170)
                    } else {
                        Text(fixedTitle ?? "")
                            .font(.subheadline)
                            .foregroundColor(isEnabled.wrappedValue ? .primary : .secondary)
                    }
                    if let sourcePath {
                        Label(sourcePath, systemImage: "externaldrive.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Spacer()
                trailingContent

                Button(action: onAdd) {
                    Image(systemName: "folder.badge.plus")
                    Text("Ajouter")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .disabled(!isEnabled.wrappedValue)
            }

            if isEnabled.wrappedValue {
                if urls.isEmpty {
                    Text("Aucun dossier sélectionné")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.leading, 32)
                } else {
                    ForEach(urls.indices, id: \.self) { index in
                        HStack {
                            Text(urls[index].path)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button { onRemove(index) } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 32)
                    }
                }
            } else {
                Text("Désactivé")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.leading, 32)
            }
        }
        .opacity(isEnabled.wrappedValue ? 1 : 0.6)
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
            if let isEnabled { Toggle("", isOn: isEnabled).labelsHidden() }
            VStack(alignment: .leading, spacing: 4) {
                if !title.isEmpty { Text(title).font(.subheadline) }
                Text(url?.path ?? "Aucun dossier sélectionné")
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(url == nil ? .red : .primary)
            }
            Spacer(minLength: 20)
            trailingContent
            Button(action: action) {
                Image(systemName: "folder.badge.plus")
                Text("Parcourir")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }
}

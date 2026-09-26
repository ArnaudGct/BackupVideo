import Foundation
import SwiftUI
import AppKit

enum CollisionResolution {
    case replace
    case merge
    case skip
}

enum CollisionType {
    case normal
    case perfectlyIdentical
}

@MainActor
@Observable
class BackupViewModel {
    var config = BackupConfiguration()
    var projects: [VideoProject] = []
    var progress = BackupProgress()

    var customBackupCategories: [CustomBackupCategory] = [] {
        didSet { saveCustomBackupCategories() }
    }

    var rushFolderName: String = UserDefaults.standard.string(forKey: "rushFolderName") ?? "Rushs" {
        didSet { UserDefaults.standard.set(rushFolderName, forKey: "rushFolderName") }
    }
    var renderFolderName: String = UserDefaults.standard.string(forKey: "renderFolderName") ?? "Rendus" {
        didSet { UserDefaults.standard.set(renderFolderName, forKey: "renderFolderName") }
    }
    var renderSubfolderName: String = UserDefaults.standard.string(forKey: "renderSubfolderName") ?? "" {
        didSet { UserDefaults.standard.set(renderSubfolderName, forKey: "renderSubfolderName") }
    }
    
    var namingFormat: ProjectNamingFormat = ProjectNamingFormat(rawValue: UserDefaults.standard.string(forKey: "namingFormat") ?? "") ?? .client_project {
        didSet {
            UserDefaults.standard.set(namingFormat.rawValue, forKey: "namingFormat")
            scanProjects() // Rescan if format changes
        }
    }
    var useRenderSubfolder: Bool = UserDefaults.standard.object(forKey: "useRenderSubfolder") as? Bool ?? false {
        didSet { UserDefaults.standard.set(useRenderSubfolder, forKey: "useRenderSubfolder") }
    }
    
    var deleteRushsInArchive: Bool = UserDefaults.standard.object(forKey: "deleteRushsInArchive") as? Bool ?? false {
        didSet { UserDefaults.standard.set(deleteRushsInArchive, forKey: "deleteRushsInArchive") }
    }
    
    var deleteRendersInArchive: Bool = UserDefaults.standard.object(forKey: "deleteRendersInArchive") as? Bool ?? false {
        didSet { UserDefaults.standard.set(deleteRendersInArchive, forKey: "deleteRendersInArchive") }
    }
    
    var enableRendersBackup: Bool = UserDefaults.standard.object(forKey: "enableRendersBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableRendersBackup, forKey: "enableRendersBackup") }
    }
    var enableProjectsBackup: Bool = UserDefaults.standard.object(forKey: "enableProjectsBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableProjectsBackup, forKey: "enableProjectsBackup") }
    }
    var enableRushBackup: Bool = UserDefaults.standard.object(forKey: "enableRushBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enableRushBackup, forKey: "enableRushBackup") }
    }
    var showRendersBackup: Bool = UserDefaults.standard.object(forKey: "showRendersBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showRendersBackup, forKey: "showRendersBackup") }
    }
    var showRushBackup: Bool = UserDefaults.standard.object(forKey: "showRushBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showRushBackup, forKey: "showRushBackup") }
    }
    var rendersFolderIsBackup: Bool = UserDefaults.standard.object(forKey: "rendersFolderIsBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(rendersFolderIsBackup, forKey: "rendersFolderIsBackup") }
    }
    var rushFolderIsBackup: Bool = UserDefaults.standard.object(forKey: "rushFolderIsBackup") as? Bool ?? true {
        didSet { UserDefaults.standard.set(rushFolderIsBackup, forKey: "rushFolderIsBackup") }
    }
    
    var globalSettings: ProjectSettings {
        ProjectSettings(
            rendersDestinationURLs: config.rendersDestinationURLs,
            projectsDestinationURLs: config.projectsDestinationURLs,
            rushDestinationURLs: config.rushDestinationURLs,
            customBackupCategories: customBackupCategories,
            enableRendersBackup: enableRendersBackup,
            enableProjectsBackup: enableProjectsBackup,
            enableRushBackup: enableRushBackup,
            showRendersBackup: showRendersBackup,
            showRushBackup: showRushBackup,
            rendersFolderIsBackup: rendersFolderIsBackup,
            rushFolderIsBackup: rushFolderIsBackup,
            deleteRushsInArchive: deleteRushsInArchive,
            deleteRendersInArchive: deleteRendersInArchive,
            rushFolderName: rushFolderName,
            renderFolderName: renderFolderName,
            renderSubfolderName: renderSubfolderName,
            useRenderSubfolder: useRenderSubfolder
        )
    }

    init() {
        let migrationKey = "dynamicArchiveExclusionsInitialized"
        if !UserDefaults.standard.bool(forKey: migrationKey) {
            deleteRushsInArchive = false
            deleteRendersInArchive = false
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }
    
    var showConfirmationDialog: Bool = false
    var showArchiveConfigPopover: Bool = false
    
    var backupReport: BackupReport?
    var showReportDialog: Bool = false
    
    private var backupTask: Task<Void, Never>?
    
    func pauseBackup() {
        progress.isPaused = true
    }
    
    func resumeBackup() {
        progress.isPaused = false
    }
    
    func stopBackup() {
        progress.isStopped = true
        progress.isPaused = false
        backupTask?.cancel()
    }
    
    var showCollisionDialog: Bool = false
    var collisionMessage: String = ""
    var collisionType: CollisionType = .normal
    var collisionResolutionContinuation: CheckedContinuation<CollisionResolution, Never>?
    
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    var requiresConfirmation: Bool {
        let selected = projects.filter { $0.isSelected }
        if config.deleteOriginalProject && !selected.isEmpty { return true }
        
        for project in selected {
            let settings = project.customSettings ?? globalSettings
            if settings.enableProjectsBackup && !settings.projectsDestinationURLs.isEmpty {
                if !archiveExclusions(for: settings).isEmpty {
                    return true
                }
            }
        }
        return false
    }

    var confirmationMessage: String {
        var items: [String] = []
        let selected = projects.filter { $0.isSelected }
        var excludedNames = Set<String>()
        for project in selected {
            let settings = project.customSettings ?? globalSettings
            guard settings.enableProjectsBackup, !settings.projectsDestinationURLs.isEmpty else { continue }
            archiveExclusions(for: settings).forEach { excludedNames.insert($0.name) }
        }
        for name in excludedNames.sorted() {
            items.append("- La sauvegarde « \(name) » sera exclue de l’archive")
        }
        if config.deleteOriginalProject {
            items.append("- Les dossiers projets originaux (Une validation finale sera exigée à la fin)")
        }
        return items.joined(separator: "\n")
    }

    private func archiveExclusions(for settings: ProjectSettings) -> [(name: String, path: String)] {
        var exclusions: [(String, String)] = []
        if settings.showRushBackup && settings.rushFolderIsBackup && settings.deleteRushsInArchive {
            exclusions.append((displayFolderPath(from: settings.rushFolderName), settings.rushFolderName))
        }
        if settings.showRendersBackup && settings.rendersFolderIsBackup && settings.deleteRendersInArchive {
            let renderPath = settings.useRenderSubfolder && !settings.renderSubfolderName.isEmpty
                ? settings.renderFolderName + "/" + settings.renderSubfolderName
                : settings.renderFolderName
            exclusions.append((displayFolderPath(from: renderPath), renderPath))
        }
        exclusions.append(contentsOf: settings.customBackupCategories
            .filter { $0.isBackup && $0.excludeFromArchive }
            .map { ($0.pathComponents.joined(separator: " / "), $0.relativePath) })
        return exclusions
    }

    private func displayFolderPath(from path: String) -> String {
        path.split(separator: "/").map(String.init).joined(separator: " / ")
    }

    private func folderName(from path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
    
    private let fileManagerService = FileManagerService()
    
    func addSourceURL() {
        if let url = showOpenPanel() {
            guard !config.sourceURLs.contains(url) else { return }
            config.sourceURLs.append(url)
            BookmarkManager.shared.saveBookmarks(for: config.sourceURLs, key: "sourceURLs")
            scanProjects()
        }
    }

    func removeSourceURL(at index: Int) {
        guard config.sourceURLs.indices.contains(index) else { return }
        config.sourceURLs.remove(at: index)
        BookmarkManager.shared.saveBookmarks(for: config.sourceURLs, key: "sourceURLs")
        scanProjects()
    }

    func addCustomBackupCategory(parentPath: [String] = []) {
        var folderName = "Nouveau dossier"
        var suffix = 2
        while allConfiguredFolderPaths.contains(parentPath + [folderName]) {
            folderName = "Nouveau dossier \(suffix)"
            suffix += 1
        }
        customBackupCategories.append(CustomBackupCategory(name: folderName, pathComponents: parentPath + [folderName], isBackup: false))
    }

    func removeCustomBackupCategory(id: UUID) {
        customBackupCategories.removeAll { $0.id == id }
    }

    func persistBackupDestinations() {
        BookmarkManager.shared.saveBookmarks(for: config.rendersDestinationURLs, key: "rendersDestinationURLs")
        BookmarkManager.shared.saveBookmarks(for: config.projectsDestinationURLs, key: "projectsDestinationURLs")
        BookmarkManager.shared.saveBookmarks(for: config.rushDestinationURLs, key: "rushDestinationURLs")
        saveCustomBackupCategories()
    }

    var allConfiguredFolderPaths: [[String]] {
        var paths = customBackupCategories.map(\.pathComponents)
        paths.append(pathComponents(from: rushFolderName))
        var renderPath = pathComponents(from: renderFolderName)
        if useRenderSubfolder { renderPath += pathComponents(from: renderSubfolderName) }
        paths.append(renderPath)
        return paths.filter { !$0.isEmpty }
    }
    
    func addRendersDestinationURL() {
        if let url = showOpenPanel() {
            config.rendersDestinationURLs.append(url)
            BookmarkManager.shared.saveBookmarks(for: config.rendersDestinationURLs, key: "rendersDestinationURLs")
        }
    }
    
    func removeRendersDestinationURL(at index: Int) {
        guard config.rendersDestinationURLs.indices.contains(index) else { return }
        config.rendersDestinationURLs.remove(at: index)
        BookmarkManager.shared.saveBookmarks(for: config.rendersDestinationURLs, key: "rendersDestinationURLs")
    }
    
    func addProjectsDestinationURL() {
        if let url = showOpenPanel() {
            config.projectsDestinationURLs.append(url)
            BookmarkManager.shared.saveBookmarks(for: config.projectsDestinationURLs, key: "projectsDestinationURLs")
        }
    }
    
    func removeProjectsDestinationURL(at index: Int) {
        guard config.projectsDestinationURLs.indices.contains(index) else { return }
        config.projectsDestinationURLs.remove(at: index)
        BookmarkManager.shared.saveBookmarks(for: config.projectsDestinationURLs, key: "projectsDestinationURLs")
    }
    
    func addRushDestinationURL() {
        if let url = showOpenPanel() {
            config.rushDestinationURLs.append(url)
            BookmarkManager.shared.saveBookmarks(for: config.rushDestinationURLs, key: "rushDestinationURLs")
        }
    }
    
    func removeRushDestinationURL(at index: Int) {
        guard config.rushDestinationURLs.indices.contains(index) else { return }
        config.rushDestinationURLs.remove(at: index)
        BookmarkManager.shared.saveBookmarks(for: config.rushDestinationURLs, key: "rushDestinationURLs")
    }
    
    private func showOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Sélectionner"
        
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
    
    func scanProjects() {
        let sourceURLs = config.sourceURLs
        guard !sourceURLs.isEmpty else {
            projects = []
            return
        }
        
        Task {
            let format = await MainActor.run(resultType: ProjectNamingFormat.self, body: { self.namingFormat })
            var newProjects: [VideoProject] = []
            for sourceURL in sourceURLs {
                do {
                    _ = BookmarkManager.shared.startAccessing(url: sourceURL)
                    defer { BookmarkManager.shared.stopAccessing(url: sourceURL) }
                    newProjects.append(contentsOf: try await fileManagerService.scanForProjects(at: sourceURL, format: format))
                } catch {
                    await MainActor.run {
                        self.log("Erreur lors du scan de \(sourceURL.path) : \(error.localizedDescription)", type: .error)
                    }
                }
            }

            var seen = Set<URL>()
            newProjects = newProjects.filter { seen.insert($0.url).inserted }

            await MainActor.run {
                for i in newProjects.indices {
                    if let existing = self.projects.first(where: { $0.url == newProjects[i].url }) {
                        newProjects[i].isSelected = existing.isSelected
                        newProjects[i].customSettings = existing.customSettings
                    }
                }
                self.projects = newProjects.sorted { $0.projectName.localizedStandardCompare($1.projectName) == .orderedAscending }
                self.log("Scanner terminé : \(self.projects.count) projets trouvés dans \(sourceURLs.count) emplacements.", type: .info)
            }
        }
    }
    
    func startBackup() {
        let selectedProjects = projects.filter { $0.isSelected }
        guard config.isValid, !selectedProjects.isEmpty else { return }
        
        progress.isRunning = true
        progress.totalProjects = selectedProjects.count
        progress.completedProjects = 0
        progress.logs.removeAll()
        
        backupTask = Task.detached {
            await self.executeBackup(for: selectedProjects)
        }
    }
    
    private func executeBackup(for selectedProjects: [VideoProject]) async {
        let checkPause: @Sendable () async throws -> Void = { [weak self] in
            while await self?.progress.isPaused == true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            try Task.checkCancellation()
        }
        
        let sources = await MainActor.run { self.config.sourceURLs }
        guard !sources.isEmpty else { return }
        let allDestinations = await MainActor.run {
            Set(selectedProjects.flatMap { project -> [URL] in
                let settings = project.customSettings ?? self.globalSettings
                return settings.rendersDestinationURLs
                    + settings.projectsDestinationURLs
                    + settings.rushDestinationURLs
                    + settings.customBackupCategories.flatMap(\.destinationURLs)
            })
        }
        
        // Start accessing all bookmarks
        for source in sources { _ = BookmarkManager.shared.startAccessing(url: source) }
        for destination in allDestinations { _ = BookmarkManager.shared.startAccessing(url: destination) }
        
        defer {
            for source in sources { BookmarkManager.shared.stopAccessing(url: source) }
            for destination in allDestinations { BookmarkManager.shared.stopAccessing(url: destination) }
            
            Task { @MainActor in
                self.progress.isRunning = false
                self.log("Processus de sauvegarde terminé.", type: .success)
                self.scanProjects() // Rescan after backup to update list
            }
        }
        
        do {
            // Calculer la taille totale requise (approximation)
            let totalRequiredSize = selectedProjects.reduce(0) { $0 + $1.totalSize }
            // On vérifie grossièrement sur la première destination projet si elle existe
            let firstProjectDest = await MainActor.run {
                selectedProjects.lazy.compactMap { ($0.customSettings ?? self.globalSettings).projectsDestinationURLs.first }.first
            }
            if let firstProjectDest {
                let hasSpace = try await fileManagerService.checkAvailableSpace(at: firstProjectDest, requiredBytes: totalRequiredSize)
                
                if !hasSpace {
                    let requiredGB = Double(totalRequiredSize) / 1_073_741_824.0
                    let msg = "Espace disque insuffisant sur la destination : \(firstProjectDest.lastPathComponent). Environ \(String(format: "%.1f", requiredGB)) Go requis."
                    await MainActor.run { 
                        self.log(msg, type: .error)
                        self.errorMessage = msg
                        self.showErrorAlert = true
                        self.progress.isRunning = false
                    }
                    return
                }
            }
            
            var currentReport = BackupReport()
            
            for project in selectedProjects {
                let settings = project.customSettings ?? self.globalSettings
                let rendersDests = settings.rendersDestinationURLs
                let projectsDests = settings.projectsDestinationURLs
                let rushsDests = settings.rushDestinationURLs
                let rendersLabel = folderName(from: settings.useRenderSubfolder && !settings.renderSubfolderName.isEmpty
                    ? settings.renderFolderName + "/" + settings.renderSubfolderName
                    : settings.renderFolderName)
                let rushLabel = folderName(from: settings.rushFolderName)
                let archiveLabel = project.url.lastPathComponent
                var projectDestinations: [String] = []
                var projectError: String? = nil
                var projectSuccess = true
                
                await MainActor.run {
                    self.progress.currentItemName = project.projectName
                    self.log("Début du traitement de \(project.projectName)...", type: .info)
                }
                
                // Etape 1: Sauvegarde des Rendus
                if settings.showRendersBackup && settings.rendersFolderIsBackup && settings.enableRendersBackup && !rendersDests.isEmpty {
                    var renduSourceURL = project.url.appendingPathComponent(settings.renderFolderName)
                    if settings.useRenderSubfolder && !settings.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                        renduSourceURL.appendPathComponent(settings.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces))
                    }
                    
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: renduSourceURL.path, isDirectory: &isDir), isDir.boolValue {
                        for renduDest in rendersDests {
                            let clientRenduDestURL = renduDest.appendingPathComponent(project.clientName)
                            try? await fileManagerService.createDirectoryIfNeeded(at: clientRenduDestURL)
                            
                            let finalRenduDestURL = clientRenduDestURL.appendingPathComponent(project.projectName)
                            
                            await MainActor.run { self.progress.currentItemName = "\(project.projectName) (\(rendersLabel))" }
                            let resolution = await handleCollision(sourceURL: renduSourceURL, destURL: finalRenduDestURL, itemName: "\(rendersLabel) de \(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rendus ignorés pour \(project.projectName)", type: .info) }
                                continue
                            }
                            
                            self.resetSpeedTracker()
                            let renduSuccess: Bool?
                            if resolution == .merge {
                                renduSuccess = try? await fileManagerService.mergeItemAndVerify(from: renduSourceURL, to: finalRenduDestURL, checkPause: checkPause) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            } else {
                                renduSuccess = try? await fileManagerService.copyItemAndVerify(from: renduSourceURL, to: finalRenduDestURL, checkPause: checkPause) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            }
                            
                            if renduSuccess == true {
                                if !projectDestinations.contains(rendersLabel) { projectDestinations.append(rendersLabel) }
                                await MainActor.run { self.log("✅ Rendus copiés avec succès : \(project.projectName) (-> \(renduDest.lastPathComponent))", type: .success) }
                            } else {
                                projectSuccess = false
                                projectError = "Échec de vérification pour les rendus sur une des destinations"
                                await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName) (-> \(renduDest.lastPathComponent))", type: .error) }
                            }
                        }
                    } else {
                        let folderDesc = (settings.useRenderSubfolder && !settings.renderSubfolderName.isEmpty) ? "\(settings.renderFolderName)/\(settings.renderSubfolderName)" : settings.renderFolderName
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(folderDesc)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }
                
                // Etape 2: Sauvegarde des Rushs (Si activé)
                if settings.showRushBackup && settings.rushFolderIsBackup && settings.enableRushBackup && !rushsDests.isEmpty {
                    let rushSourceURL = project.url.appendingPathComponent(settings.rushFolderName)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: rushSourceURL.path, isDirectory: &isDir) {
                        for rushDest in rushsDests {
                            let clientRushDestURL = rushDest.appendingPathComponent(project.clientName)
                            try? await fileManagerService.createDirectoryIfNeeded(at: clientRushDestURL)
                            
                            let finalRushDestURL = clientRushDestURL.appendingPathComponent(project.projectName)
                            
                            await MainActor.run { 
                                self.progress.currentItemName = "\(project.projectName) (\(rushLabel))"
                                self.log("Copie des Rushs pour \(project.projectName) (-> \(rushDest.lastPathComponent))...", type: .info) 
                            }
                            
                            let resolution = await handleCollision(sourceURL: rushSourceURL, destURL: finalRushDestURL, itemName: "\(rushLabel) de \(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rushs ignorés pour \(project.projectName)", type: .info) }
                                continue
                            }
                            
                            self.resetSpeedTracker()
                            let success: Bool?
                            if resolution == .merge {
                                success = try? await fileManagerService.mergeItemAndVerify(from: rushSourceURL, to: finalRushDestURL, checkPause: checkPause) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            } else {
                                success = try? await fileManagerService.copyItemAndVerify(from: rushSourceURL, to: finalRushDestURL, checkPause: checkPause) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            }
                            if success == true {
                                if !projectDestinations.contains(rushLabel) { projectDestinations.append(rushLabel) }
                                await MainActor.run { self.log("✅ Rushs \(project.projectName) copiés avec succès (-> \(rushDest.lastPathComponent)).", type: .success) }
                            } else {
                                projectSuccess = false
                                projectError = "Erreur de vérification des Rushs sur une des destinations"
                                await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName) (-> \(rushDest.lastPathComponent))", type: .error) }
                            }
                        }
                    } else {
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(settings.rushFolderName)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }

                // Etape 3: Sauvegardes personnalisées (Musique, Sound Design, etc.)
                for category in settings.customBackupCategories where category.isBackup && category.isEnabled && !category.destinationURLs.isEmpty {
                    let categorySourceURL = category.pathComponents.reduce(project.url) {
                        $0.appendingPathComponent($1, isDirectory: true)
                    }
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: categorySourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                        await MainActor.run {
                            self.log("⚠️ Aucun dossier '\(category.relativePath)' trouvé pour \(project.projectName)", type: .warning)
                        }
                        continue
                    }

                    for destination in category.destinationURLs {
                        let clientDestination = destination.appendingPathComponent(project.clientName)
                        try? await fileManagerService.createDirectoryIfNeeded(at: clientDestination)
                        let finalDestination = clientDestination.appendingPathComponent(project.projectName)

                        await MainActor.run {
                            self.progress.currentItemName = "\(project.projectName) (\(category.folderName))"
                            self.log("Copie de \(category.folderName) pour \(project.projectName) (-> \(destination.lastPathComponent))...", type: .info)
                        }

                        let resolution = await handleCollision(
                            sourceURL: categorySourceURL,
                            destURL: finalDestination,
                            itemName: "\(category.folderName) de \(project.projectName)"
                        )
                        if resolution == .skip { continue }

                        self.resetSpeedTracker()
                        let success: Bool?
                        if resolution == .merge {
                            success = try? await fileManagerService.mergeItemAndVerify(from: categorySourceURL, to: finalDestination, checkPause: checkPause) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        } else {
                            success = try? await fileManagerService.copyItemAndVerify(from: categorySourceURL, to: finalDestination, checkPause: checkPause) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        }

                        if success == true {
                            if !projectDestinations.contains(category.folderName) { projectDestinations.append(category.folderName) }
                            await MainActor.run { self.log("✅ \(category.folderName) copié avec succès (-> \(destination.lastPathComponent)).", type: .success) }
                        } else {
                            projectSuccess = false
                            projectError = "Erreur de vérification pour \(category.folderName)"
                            await MainActor.run { self.log("❌ \(projectError!)", type: .error) }
                        }
                    }
                }
                
                // Etape 4: Sauvegarde du projet entier (Archive)
                var archSuccessGlobal = true
                if settings.enableProjectsBackup && !projectsDests.isEmpty {
                    for projectsDest in projectsDests {
                        let clientProjectDestURL = projectsDest.appendingPathComponent(project.clientName)
                        try? await fileManagerService.createDirectoryIfNeeded(at: clientProjectDestURL)
                        
                        let finalProjectDestURL = clientProjectDestURL.appendingPathComponent(project.url.lastPathComponent)
                        
                        await MainActor.run { 
                            self.progress.currentItemName = "\(project.projectName) (\(archiveLabel))"
                            self.log("Copie du projet pour \(project.projectName) (-> \(projectsDest.lastPathComponent))...", type: .info) 
                        }
                        
                        let excludedRootFolders = archiveExclusions(for: settings).map(\.path)
                        
                        let resolution = await handleCollision(
                            sourceURL: project.url,
                            destURL: finalProjectDestURL,
                            itemName: "\(archiveLabel) — \(project.projectName)",
                            excludedRootFolders: excludedRootFolders
                        )
                        if resolution == .skip {
                            await MainActor.run { self.log("⏭️ Projet ignoré pour \(project.projectName)", type: .info) }
                            continue
                        }
                        
                        self.resetSpeedTracker()
                        let archSuccess: Bool?
                        if resolution == .merge {
                            archSuccess = try? await fileManagerService.mergeItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders, checkPause: checkPause) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        } else {
                            archSuccess = try? await fileManagerService.copyItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders, checkPause: checkPause) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        }
                        
                        if archSuccess == true {
                            if !projectDestinations.contains(archiveLabel) { projectDestinations.append(archiveLabel) }
                            await MainActor.run { self.log("✅ Projet \(project.projectName) archivé avec succès (-> \(projectsDest.lastPathComponent)).", type: .success) }
                            
                            // Etape 4 : Pas de nettoyage post-transfert (Les dossiers ont été ignorés à la volée pendant la copie grâce à exclusions)
                        } else {
                            archSuccessGlobal = false
                            projectSuccess = false
                            projectError = "Échec de vérification de l'archive sur une des destinations"
                            await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName) (-> \(projectsDest.lastPathComponent))", type: .error) }
                        }
                    }
                }
                
                if settings.enableProjectsBackup && !archSuccessGlobal {
                    currentReport.addResult(project: project, success: false, destinations: projectDestinations, errorDescription: projectError)
                } else if projectSuccess {
                    currentReport.addResult(project: project, success: true, destinations: projectDestinations)
                } else {
                    currentReport.addResult(project: project, success: false, destinations: projectDestinations, errorDescription: projectError)
                }
                
                await MainActor.run {
                    self.progress.completedProjects += 1
                }
            }
            
            await MainActor.run {
                self.progress.isRunning = false
                self.backupReport = currentReport
                self.showReportDialog = true
            }
            
        } catch {
            await MainActor.run {
                self.log("Erreur critique: \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    private func log(_ message: String, type: LogEntry.LogType) {
        progress.logs.append(LogEntry(message: message, type: type))
        let prefix: String
        switch type {
        case .info: prefix = "INFO"
        case .success: prefix = "SUCCESS"
        case .warning: prefix = "WARNING"
        case .error: prefix = "ERROR"
        }
        LoggerService.shared.log("[\(prefix)] \(message)")
    }
    
    func confirmDeletionAndFinish() {
        guard let report = backupReport else { return }
        
        Task.detached {
            for project in report.successfulProjects {
                do {
                    try FileManager.default.removeItem(at: project.url)
                    await MainActor.run { self.log("🗑️ Source supprimée définitivement : \(project.projectName)", type: .info) }
                } catch {
                    await MainActor.run { self.log("❌ Erreur lors de la suppression de \(project.projectName) : \(error.localizedDescription)", type: .error) }
                }
            }
            
            await MainActor.run {
                self.showReportDialog = false
                self.backupReport = nil
                self.scanProjects()
            }
        }
    }
    
    func closeReport() {
        self.showReportDialog = false
        self.backupReport = nil
        self.scanProjects()
    }
    
    func restoreBookmarks() {
        var sources = BookmarkManager.shared.getURLs(forKey: "sourceURLs")
        if sources.isEmpty, let legacySource = BookmarkManager.shared.getURL(forKey: "sourceURL") { sources = [legacySource] }
        config.sourceURLs = sources
        
        let renders = BookmarkManager.shared.getURLs(forKey: "rendersDestinationURLs")
        if !renders.isEmpty { config.rendersDestinationURLs = renders }
        
        let projects = BookmarkManager.shared.getURLs(forKey: "projectsDestinationURLs")
        if !projects.isEmpty { config.projectsDestinationURLs = projects }
        
        let rushs = BookmarkManager.shared.getURLs(forKey: "rushDestinationURLs")
        if !rushs.isEmpty { config.rushDestinationURLs = rushs }

        if let data = UserDefaults.standard.data(forKey: "customBackupCategories"),
           var categories = try? JSONDecoder().decode([CustomBackupCategory].self, from: data) {
            for index in categories.indices {
                categories[index].destinationURLs = BookmarkManager.shared.getURLs(forKey: "customBackupCategory.\(categories[index].id.uuidString)")
            }
            customBackupCategories = categories
        }
        scanProjects()
    }

    private func saveCustomBackupCategories() {
        var metadata = customBackupCategories
        for index in metadata.indices { metadata[index].destinationURLs = [] }
        if let data = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(data, forKey: "customBackupCategories")
        }
        for category in customBackupCategories {
            BookmarkManager.shared.saveBookmarks(for: category.destinationURLs, key: "customBackupCategory.\(category.id.uuidString)")
        }
    }

    func pathComponents(from path: String) -> [String] {
        path.split(separator: "/").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    // Suivi de progression et vitesse
    private var lastProgressDate: Date? = nil
    private var lastCopiedBytes: Int64 = 0
    
    private func resetSpeedTracker() {
        Task { @MainActor in
            self.lastProgressDate = nil
            self.lastCopiedBytes = 0
            self.progress.speedMBps = 0.0
            self.progress.estimatedTimeRemaining = nil
        }
    }
    
    private func handleProgress(copied: Int64, total: Int64) {
        Task { @MainActor in
            self.progress.copiedBytes = copied
            self.progress.totalBytes = total
            self.progress.currentFileProgress = total > 0 ? Double(copied) / Double(total) : 0.0
            
            let now = Date()
            if let lastDate = self.lastProgressDate {
                let timeDelta = now.timeIntervalSince(lastDate)
                if timeDelta >= 1.0 { // Mise à jour de la vitesse toutes les secondes
                    let bytesDelta = copied - self.lastCopiedBytes
                    let speedMBps = Double(bytesDelta) / timeDelta / 1_048_576.0
                    self.progress.speedMBps = max(0, speedMBps)
                    
                    if speedMBps > 0 {
                        self.progress.estimatedTimeRemaining = Double(total - copied) / 1_048_576.0 / speedMBps
                    }
                    
                    self.lastProgressDate = now
                    self.lastCopiedBytes = copied
                }
            } else {
                self.lastProgressDate = now
                self.lastCopiedBytes = copied
            }
        }
    }
}

extension BackupViewModel {
    func handleCollision(sourceURL: URL, destURL: URL, itemName: String, excludedRootFolders: [String] = []) async -> CollisionResolution {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: destURL.path) else { return .replace }

        let sourceSize = FileManagerService().calculateSize(at: sourceURL, excludedRootFolders: excludedRootFolders)
        let destSize = FileManagerService().calculateSize(at: destURL)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sSource = formatter.string(fromByteCount: sourceSize)
        let sDest = formatter.string(fromByteCount: destSize)
        
        var message = "Le dossier \(itemName) existe déjà sur la destination (\(destURL.lastPathComponent)).\n\n"
        message += "• Source : \(sSource)\n"
        message += "• Destination existante : \(sDest)\n\n"
        
        var type: CollisionType = .normal

        let contentsAreIdentical = FileManagerService().itemsAreEquivalent(
            from: sourceURL,
            to: destURL,
            excludedRootFolders: excludedRootFolders
        )

        if contentsAreIdentical {
            message += "✅ L’arborescence et le contenu de chaque fichier sont identiques."
            type = .perfectlyIdentical
        } else if sourceSize == destSize {
            message += "⚠️ Les tailles sont identiques, mais le contenu d’au moins un fichier diffère."
        } else if sourceSize > destSize {
            message += "⚠️ La source est plus volumineuse. Il manque probablement des éléments sur la destination."
        } else {
            message += "⚠️ La destination est plus volumineuse."
        }
        
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.collisionType = type
                self.collisionMessage = message
                self.collisionResolutionContinuation = continuation
                self.showCollisionDialog = true
            }
        }
    }
    
    func resolveCollision(_ resolution: CollisionResolution) {
        self.showCollisionDialog = false
        if let continuation = self.collisionResolutionContinuation {
            self.collisionResolutionContinuation = nil
            continuation.resume(returning: resolution)
        }
    }
}

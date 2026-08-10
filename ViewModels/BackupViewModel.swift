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
    
    var rushFolderName: String = UserDefaults.standard.string(forKey: "rushFolderName") ?? "1 - Rushs" {
        didSet { UserDefaults.standard.set(rushFolderName, forKey: "rushFolderName") }
    }
    var renderFolderName: String = UserDefaults.standard.string(forKey: "renderFolderName") ?? "3 - Rendus" {
        didSet { UserDefaults.standard.set(renderFolderName, forKey: "renderFolderName") }
    }
    var renderSubfolderName: String = UserDefaults.standard.string(forKey: "renderSubfolderName") ?? "Def" {
        didSet { UserDefaults.standard.set(renderSubfolderName, forKey: "renderSubfolderName") }
    }
    
    var namingFormat: ProjectNamingFormat = ProjectNamingFormat(rawValue: UserDefaults.standard.string(forKey: "namingFormat") ?? "") ?? .client_project {
        didSet {
            UserDefaults.standard.set(namingFormat.rawValue, forKey: "namingFormat")
            scanProjects() // Rescan if format changes
        }
    }
    var useRenderSubfolder: Bool = UserDefaults.standard.object(forKey: "useRenderSubfolder") as? Bool ?? true {
        didSet { UserDefaults.standard.set(useRenderSubfolder, forKey: "useRenderSubfolder") }
    }
    
    var deleteRushsInArchive: Bool = UserDefaults.standard.object(forKey: "deleteRushsInArchive") as? Bool ?? true {
        didSet { UserDefaults.standard.set(deleteRushsInArchive, forKey: "deleteRushsInArchive") }
    }
    
    var deleteRendersInArchive: Bool = UserDefaults.standard.object(forKey: "deleteRendersInArchive") as? Bool ?? true {
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
    
    var showConfirmationDialog: Bool = false
    var showArchiveConfigPopover: Bool = false
    
    var backupReport: BackupReport?
    var showReportDialog: Bool = false
    
    var showCollisionDialog: Bool = false
    var collisionMessage: String = ""
    var collisionType: CollisionType = .normal
    var collisionResolutionContinuation: CheckedContinuation<CollisionResolution, Never>?
    
    var showErrorAlert: Bool = false
    var errorMessage: String = ""
    
    var confirmationMessage: String {
        var items: [String] = []
        if deleteRushsInArchive {
            items.append("- Le contenu des dossiers Rushs (dans l'archive)")
        }
        if deleteRendersInArchive {
            items.append("- Le contenu des dossiers Rendus (dans l'archive)")
        }
        if config.deleteOriginalProject {
            items.append("- Les dossiers projets originaux (Une validation finale sera exigée à la fin)")
        }
        return items.joined(separator: "\n")
    }
    
    private let fileManagerService = FileManagerService()
    
    func selectSourceURL() {
        if let url = showOpenPanel() {
            BookmarkManager.shared.saveBookmark(for: url, key: "sourceURL")
            config.sourceURL = url
            scanProjects()
        }
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
        guard let sourceURL = config.sourceURL else { return }
        
        Task {
            do {
                _ = BookmarkManager.shared.startAccessing(url: sourceURL)
                defer { BookmarkManager.shared.stopAccessing(url: sourceURL) }
                
                let format = await MainActor.run(resultType: ProjectNamingFormat.self, body: { self.namingFormat })
                projects = try await fileManagerService.scanForProjects(at: sourceURL, format: format)
                log("Scanner terminé : \(projects.count) projets trouvés.", type: .info)
            } catch {
                log("Erreur lors du scan : \(error.localizedDescription)", type: .error)
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
        
        Task.detached {
            await self.executeBackup(for: selectedProjects)
        }
    }
    
    private func executeBackup(for selectedProjects: [VideoProject]) async {
        guard let source = await MainActor.run(resultType: URL?.self, body: { self.config.sourceURL }) else { return }
        
        let rendersDests = await MainActor.run { self.config.rendersDestinationURLs }
        let projectsDests = await MainActor.run { self.config.projectsDestinationURLs }
        let rushsDests = await MainActor.run { self.config.rushDestinationURLs }
        
        // Start accessing all bookmarks
        _ = BookmarkManager.shared.startAccessing(url: source)
        for dest in rendersDests { _ = BookmarkManager.shared.startAccessing(url: dest) }
        for dest in projectsDests { _ = BookmarkManager.shared.startAccessing(url: dest) }
        for dest in rushsDests { _ = BookmarkManager.shared.startAccessing(url: dest) }
        
        defer {
            BookmarkManager.shared.stopAccessing(url: source)
            for dest in rendersDests { BookmarkManager.shared.stopAccessing(url: dest) }
            for dest in projectsDests { BookmarkManager.shared.stopAccessing(url: dest) }
            for dest in rushsDests { BookmarkManager.shared.stopAccessing(url: dest) }
            
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
            if let firstProjectDest = projectsDests.first {
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
                var projectDestinations: [String] = []
                var projectError: String? = nil
                var projectSuccess = true
                
                await MainActor.run {
                    self.progress.currentItemName = project.projectName
                    self.log("Début du traitement de \(project.projectName)...", type: .info)
                }
                
                // Etape 1: Sauvegarde des Rendus
                if self.enableRendersBackup && !rendersDests.isEmpty {
                    var renduSourceURL = project.url.appendingPathComponent(self.renderFolderName)
                    if self.useRenderSubfolder && !self.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                        renduSourceURL.appendPathComponent(self.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces))
                    }
                    
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: renduSourceURL.path, isDirectory: &isDir), isDir.boolValue {
                        for renduDest in rendersDests {
                            let clientRenduDestURL = renduDest.appendingPathComponent(project.clientName)
                            try? await fileManagerService.createDirectoryIfNeeded(at: clientRenduDestURL)
                            
                            let finalRenduDestURL = clientRenduDestURL.appendingPathComponent(project.url.lastPathComponent)
                            
                            await MainActor.run { self.progress.currentItemName = "\(project.projectName) (Rendus)" }
                            let resolution = await handleCollision(destURL: finalRenduDestURL, sourceSize: fileManagerService.calculateSize(at: renduSourceURL), itemName: "Rendus de \(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rendus ignorés pour \(project.projectName)", type: .info) }
                                continue
                            }
                            
                            self.resetSpeedTracker()
                            let renduSuccess: Bool?
                            if resolution == .merge {
                                renduSuccess = try? await fileManagerService.mergeItemAndVerify(from: renduSourceURL, to: finalRenduDestURL) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            } else {
                                renduSuccess = try? await fileManagerService.copyItemAndVerify(from: renduSourceURL, to: finalRenduDestURL) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            }
                            
                            if renduSuccess == true {
                                if !projectDestinations.contains("Rendus") { projectDestinations.append("Rendus") }
                                await MainActor.run { self.log("✅ Rendus copiés avec succès : \(project.projectName) (-> \(renduDest.lastPathComponent))", type: .success) }
                            } else {
                                projectSuccess = false
                                projectError = "Échec de vérification pour les rendus sur une des destinations"
                                await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName) (-> \(renduDest.lastPathComponent))", type: .error) }
                            }
                        }
                    } else {
                        let folderDesc = (self.useRenderSubfolder && !self.renderSubfolderName.isEmpty) ? "\(self.renderFolderName)/\(self.renderSubfolderName)" : self.renderFolderName
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(folderDesc)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }
                
                // Etape 2: Sauvegarde des Rushs (Si activé)
                if self.enableRushBackup && !rushsDests.isEmpty {
                    let rushSourceURL = project.url.appendingPathComponent(self.rushFolderName)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: rushSourceURL.path, isDirectory: &isDir) {
                        for rushDest in rushsDests {
                            let clientRushDestURL = rushDest.appendingPathComponent(project.clientName)
                            try? await fileManagerService.createDirectoryIfNeeded(at: clientRushDestURL)
                            
                            let finalRushDestURL = clientRushDestURL.appendingPathComponent(project.url.lastPathComponent)
                            
                            await MainActor.run { 
                                self.progress.currentItemName = "\(project.projectName) (Rushs)"
                                self.log("Copie des Rushs pour \(project.projectName) (-> \(rushDest.lastPathComponent))...", type: .info) 
                            }
                            
                            let resolution = await handleCollision(destURL: finalRushDestURL, sourceSize: fileManagerService.calculateSize(at: rushSourceURL), itemName: "Rushs de \(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rushs ignorés pour \(project.projectName)", type: .info) }
                                continue
                            }
                            
                            self.resetSpeedTracker()
                            let success: Bool?
                            if resolution == .merge {
                                success = try? await fileManagerService.mergeItemAndVerify(from: rushSourceURL, to: finalRushDestURL) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            } else {
                                success = try? await fileManagerService.copyItemAndVerify(from: rushSourceURL, to: finalRushDestURL) { [weak self] copied, total in
                                    Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                                }
                            }
                            if success == true {
                                if !projectDestinations.contains("Rushs") { projectDestinations.append("Rushs") }
                                await MainActor.run { self.log("✅ Rushs \(project.projectName) copiés avec succès (-> \(rushDest.lastPathComponent)).", type: .success) }
                            } else {
                                projectSuccess = false
                                projectError = "Erreur de vérification des Rushs sur une des destinations"
                                await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName) (-> \(rushDest.lastPathComponent))", type: .error) }
                            }
                        }
                    } else {
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(self.rushFolderName)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }
                
                // Etape 3: Sauvegarde du projet entier (Archive)
                var archSuccessGlobal = true
                if self.enableProjectsBackup && !projectsDests.isEmpty {
                    for projectsDest in projectsDests {
                        let clientProjectDestURL = projectsDest.appendingPathComponent(project.clientName)
                        try? await fileManagerService.createDirectoryIfNeeded(at: clientProjectDestURL)
                        
                        let finalProjectDestURL = clientProjectDestURL.appendingPathComponent(project.url.lastPathComponent)
                        
                        await MainActor.run { 
                            self.progress.currentItemName = "\(project.projectName) (Archive)"
                            self.log("Copie du projet pour \(project.projectName) (-> \(projectsDest.lastPathComponent))...", type: .info) 
                        }
                        
                        var excludedRootFolders: [String] = []
                        if self.deleteRushsInArchive { excludedRootFolders.append(self.rushFolderName) }
                        if self.deleteRendersInArchive { excludedRootFolders.append(self.renderFolderName) }
                        
                        let sourceSize = fileManagerService.calculateSize(at: project.url, excludedRootFolders: excludedRootFolders)
                        let resolution = await handleCollision(destURL: finalProjectDestURL, sourceSize: sourceSize, itemName: "Projet \(project.projectName)", expectedMissingBytes: 0)
                        if resolution == .skip {
                            await MainActor.run { self.log("⏭️ Projet ignoré pour \(project.projectName)", type: .info) }
                            continue
                        }
                        
                        self.resetSpeedTracker()
                        let archSuccess: Bool?
                        if resolution == .merge {
                            archSuccess = try? await fileManagerService.mergeItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        } else {
                            archSuccess = try? await fileManagerService.copyItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        }
                        
                        if archSuccess == true {
                            if !projectDestinations.contains("Archive") { projectDestinations.append("Archive") }
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
                
                if self.enableProjectsBackup && !archSuccessGlobal {
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
        if let source = BookmarkManager.shared.getURL(forKey: "sourceURL") {
            config.sourceURL = source
            scanProjects()
        }
        
        let renders = BookmarkManager.shared.getURLs(forKey: "rendersDestinationURLs")
        if !renders.isEmpty { config.rendersDestinationURLs = renders }
        
        let projects = BookmarkManager.shared.getURLs(forKey: "projectsDestinationURLs")
        if !projects.isEmpty { config.projectsDestinationURLs = projects }
        
        let rushs = BookmarkManager.shared.getURLs(forKey: "rushDestinationURLs")
        if !rushs.isEmpty { config.rushDestinationURLs = rushs }
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
    func handleCollision(destURL: URL, sourceSize: Int64, itemName: String, expectedMissingBytes: Int64 = 0) async -> CollisionResolution {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: destURL.path) else { return .replace }
        
        let destSize = FileManagerService().calculateSize(at: destURL)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sSource = formatter.string(fromByteCount: sourceSize)
        let sDest = formatter.string(fromByteCount: destSize)
        
        var message = "Le dossier \(itemName) existe déjà sur la destination (\(destURL.lastPathComponent)).\n\n"
        message += "• Source : \(sSource)\n"
        message += "• Destination existante : \(sDest)\n\n"
        
        let adjustedSourceSize = sourceSize - expectedMissingBytes
        
        var type: CollisionType = .normal
        
        if sourceSize == destSize {
            message += "✅ Les tailles sont identiques. Les dossiers semblent similaires."
            type = .perfectlyIdentical
        } else if expectedMissingBytes > 0 && abs(adjustedSourceSize - destSize) < 20_000_000 {
            let sMissing = formatter.string(fromByteCount: expectedMissingBytes)
            message += "✅ La différence de taille correspond exactement (\(sMissing)) aux dossiers que vous avez choisi d'exclure de l'archive ! L'archive est donc parfaitement à jour."
            type = .perfectlyIdentical
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

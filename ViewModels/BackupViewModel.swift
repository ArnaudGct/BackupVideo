import Foundation
import SwiftUI
import AppKit

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
    
    func selectRendersDestinationURL() {
        if let url = showOpenPanel() {
            BookmarkManager.shared.saveBookmark(for: url, key: "rendersDestinationURL")
            config.rendersDestinationURL = url
        }
    }
    
    func selectProjectsDestinationURL() {
        if let url = showOpenPanel() {
            BookmarkManager.shared.saveBookmark(for: url, key: "projectsDestinationURL")
            config.projectsDestinationURL = url
        }
    }
    
    func selectRushDestinationURL() {
        if let url = showOpenPanel() {
            BookmarkManager.shared.saveBookmark(for: url, key: "rushDestinationURL")
            config.rushDestinationURL = url
        }
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
        guard let source = await MainActor.run(resultType: URL?.self, body: { self.config.sourceURL }),
              let rendersDest = await MainActor.run(resultType: URL?.self, body: { self.config.rendersDestinationURL }),
              let projectsDest = await MainActor.run(resultType: URL?.self, body: { self.config.projectsDestinationURL }) else { return }
              
        // Start accessing all bookmarks
        _ = BookmarkManager.shared.startAccessing(url: source)
        _ = BookmarkManager.shared.startAccessing(url: rendersDest)
        _ = BookmarkManager.shared.startAccessing(url: projectsDest)
        
        defer {
            BookmarkManager.shared.stopAccessing(url: source)
            BookmarkManager.shared.stopAccessing(url: rendersDest)
            BookmarkManager.shared.stopAccessing(url: projectsDest)
            
            Task { @MainActor in
                self.progress.isRunning = false
                self.log("Processus de sauvegarde terminé.", type: .success)
                self.scanProjects() // Rescan after backup to update list
            }
        }
        
        do {
            // Calculer la taille totale requise (approximation)
            let totalRequiredSize = selectedProjects.reduce(0) { $0 + $1.totalSize }
            // On vérifie grossièrement sur la destination projet
            let hasSpace = try await fileManagerService.checkAvailableSpace(at: projectsDest, requiredBytes: totalRequiredSize)
            
            if !hasSpace {
                await MainActor.run { self.log("Espace disque insuffisant sur la destination.", type: .error) }
                return
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
                if self.enableRendersBackup, let renduDest = await MainActor.run(resultType: URL?.self, body: { self.config.rendersDestinationURL }) {
                    var renduSourceURL = project.url.appendingPathComponent(self.renderFolderName)
                    if self.useRenderSubfolder && !self.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                        renduSourceURL.appendPathComponent(self.renderSubfolderName.trimmingCharacters(in: CharacterSet.whitespaces))
                    }
                    
                    let clientRenduDestURL = renduDest.appendingPathComponent(project.clientName)
                    
                    try await fileManagerService.createDirectoryIfNeeded(at: clientRenduDestURL)
                    
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: renduSourceURL.path, isDirectory: &isDir), isDir.boolValue {
                        let finalRenduDestURL = clientRenduDestURL.appendingPathComponent(project.url.lastPathComponent)
                        self.resetSpeedTracker()
                        let renduSuccess = try await fileManagerService.copyItemAndVerify(from: renduSourceURL, to: finalRenduDestURL) { copied, total in
                            self.handleProgress(copied: copied, total: total)
                        }
                        
                        if renduSuccess {
                            projectDestinations.append("Rendus")
                            await MainActor.run { self.log("✅ Rendus copiés avec succès : \(project.projectName)", type: .success) }
                        } else {
                            projectSuccess = false
                            projectError = "Échec de vérification pour les rendus"
                            await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName)", type: .error) }
                            currentReport.addResult(project: project, success: false, destinations: projectDestinations, errorDescription: projectError)
                            continue 
                        }
                    } else {
                        let folderDesc = (self.useRenderSubfolder && !self.renderSubfolderName.isEmpty) ? "\(self.renderFolderName)/\(self.renderSubfolderName)" : self.renderFolderName
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(folderDesc)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }
                
                // Etape 2: Sauvegarde des Rushs (Si activé)
                if self.enableRushBackup, let rushDest = await MainActor.run(resultType: URL?.self, body: { self.config.rushDestinationURL }) {
                    let rushSourceURL = project.url.appendingPathComponent(self.rushFolderName)
                    let clientRushDestURL = rushDest.appendingPathComponent(project.clientName)
                    try await fileManagerService.createDirectoryIfNeeded(at: clientRushDestURL)
                    
                    let finalRushDestURL = clientRushDestURL.appendingPathComponent(project.url.lastPathComponent)
                    
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: rushSourceURL.path, isDirectory: &isDir) {
                        await MainActor.run { self.log("Copie des Rushs pour \(project.projectName)...", type: .info) }
                        self.resetSpeedTracker()
                        let success = try await fileManagerService.copyItemAndVerify(from: rushSourceURL, to: finalRushDestURL) { copied, total in
                            self.handleProgress(copied: copied, total: total)
                        }
                        if success {
                            projectDestinations.append("Rushs")
                            await MainActor.run { self.log("✅ Rushs \(project.projectName) copiés avec succès.", type: .success) }
                        } else {
                            projectSuccess = false
                            projectError = "Erreur de vérification des Rushs"
                            await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName)", type: .error) }
                            currentReport.addResult(project: project, success: false, destinations: projectDestinations, errorDescription: projectError)
                            continue
                        }
                    } else {
                        await MainActor.run { self.log("⚠️ Aucun dossier '\(self.rushFolderName)' trouvé pour \(project.projectName)", type: .warning) }
                    }
                }
                
                // Etape 3: Sauvegarde du projet entier (Archive)
                var archSuccess = false
                if self.enableProjectsBackup, let projectsDest = await MainActor.run(resultType: URL?.self, body: { self.config.projectsDestinationURL }) {
                    let clientProjectDestURL = projectsDest.appendingPathComponent(project.clientName)
                    try await fileManagerService.createDirectoryIfNeeded(at: clientProjectDestURL)
                    
                    let finalProjectDestURL = clientProjectDestURL.appendingPathComponent(project.url.lastPathComponent)
                    
                    await MainActor.run { self.log("Copie du projet pour \(project.projectName)...", type: .info) }
                    
                    self.resetSpeedTracker()
                    archSuccess = try await fileManagerService.copyItemAndVerify(from: project.url, to: finalProjectDestURL) { copied, total in
                        self.handleProgress(copied: copied, total: total)
                    }
                    
                    if archSuccess {
                        projectDestinations.append("Archive")
                        await MainActor.run { self.log("✅ Projet \(project.projectName) archivé avec succès.", type: .success) }
                        
                        // Etape 4: Nettoyage Post-Transfert
                        let copiedRushsURL = finalProjectDestURL.appendingPathComponent(self.rushFolderName)
                        let copiedRenduURL = finalProjectDestURL.appendingPathComponent(self.renderFolderName)
                        
                        if deleteRushsInArchive || deleteRendersInArchive {
                            await MainActor.run { self.log("Nettoyage des dossiers dans l'archive...", type: .info) }
                        }
                        
                        if deleteRushsInArchive {
                            try? await fileManagerService.emptyDirectory(at: copiedRushsURL)
                            await MainActor.run { self.log("🗑️ Contenu des Rushs supprimé dans l'archive.", type: .info) }
                        }
                        
                        if deleteRendersInArchive {
                            try? await fileManagerService.emptyDirectory(at: copiedRenduURL)
                            await MainActor.run { self.log("🗑️ Contenu des Rendus supprimé dans l'archive.", type: .info) }
                        }
                    }
                }
                
                if self.enableProjectsBackup && !archSuccess {
                    projectSuccess = false
                    projectError = "Échec de vérification de l'archive"
                    await MainActor.run { self.log("❌ \(projectError!) : \(project.projectName)", type: .error) }
                    currentReport.addResult(project: project, success: false, destinations: projectDestinations, errorDescription: projectError)
                } else {
                    currentReport.addResult(project: project, success: true, destinations: projectDestinations)
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
        if let renders = BookmarkManager.shared.getURL(forKey: "rendersDestinationURL") {
            config.rendersDestinationURL = renders
        }
        if let projects = BookmarkManager.shared.getURL(forKey: "projectsDestinationURL") {
            config.projectsDestinationURL = projects
        }
        if let rushs = BookmarkManager.shared.getURL(forKey: "rushDestinationURL") {
            config.rushDestinationURL = rushs
        }
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

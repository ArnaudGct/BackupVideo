import re

path = 'ViewModels/BackupViewModel.swift'
with open(path, 'r') as f:
    content = f.read()

# Add pause and stop methods, and backupTask
target1 = "    var showCollisionDialog: Bool = false"
replacement1 = """    private var backupTask: Task<Void, Never>?
    
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
    
    var showCollisionDialog: Bool = false"""
content = content.replace(target1, replacement1)


# Refactor confirmationMessage and requiresConfirmation
target2 = """    var confirmationMessage: String {
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
        return items.joined(separator: "\\n")
    }"""
replacement2 = """    var requiresConfirmation: Bool {
        let selected = projects.filter { $0.isSelected }
        if config.deleteOriginalProject && !selected.isEmpty { return true }
        
        for project in selected {
            let settings = project.customSettings ?? globalSettings
            if settings.enableProjectsBackup && !settings.projectsDestinationURLs.isEmpty {
                if settings.deleteRushsInArchive || settings.deleteRendersInArchive {
                    return true
                }
            }
        }
        return false
    }

    var confirmationMessage: String {
        var items: [String] = []
        let selected = projects.filter { $0.isSelected }
        let anyDeletesRush = selected.contains { ($0.customSettings ?? globalSettings).enableProjectsBackup && !($0.customSettings ?? globalSettings).projectsDestinationURLs.isEmpty && ($0.customSettings ?? globalSettings).deleteRushsInArchive }
        let anyDeletesRenders = selected.contains { ($0.customSettings ?? globalSettings).enableProjectsBackup && !($0.customSettings ?? globalSettings).projectsDestinationURLs.isEmpty && ($0.customSettings ?? globalSettings).deleteRendersInArchive }
        
        if anyDeletesRush {
            items.append("- Le contenu des dossiers Rushs (dans l'archive)")
        }
        if anyDeletesRenders {
            items.append("- Le contenu des dossiers Rendus (dans l'archive)")
        }
        if config.deleteOriginalProject {
            items.append("- Les dossiers projets originaux (Une validation finale sera exigée à la fin)")
        }
        return items.joined(separator: "\\n")
    }"""
content = content.replace(target2, replacement2)


# Refactor scanProjects
target3 = """                let format = await MainActor.run(resultType: ProjectNamingFormat.self, body: { self.namingFormat })
                projects = try await fileManagerService.scanForProjects(at: sourceURL, format: format)
                log("Scanner terminé : \\(projects.count) projets trouvés.", type: .info)"""
replacement3 = """                let format = await MainActor.run(resultType: ProjectNamingFormat.self, body: { self.namingFormat })
                var newProjects = try await fileManagerService.scanForProjects(at: sourceURL, format: format)
                
                await MainActor.run {
                    for i in 0..<newProjects.count {
                        if let existing = self.projects.first(where: { $0.url == newProjects[i].url }) {
                            newProjects[i].isSelected = existing.isSelected
                            newProjects[i].customSettings = existing.customSettings
                        }
                    }
                    self.projects = newProjects
                    self.log("Scanner terminé : \\(self.projects.count) projets trouvés.", type: .info)
                }"""
content = content.replace(target3, replacement3)


# Refactor startBackup to save backupTask
target4 = """        Task.detached {
            await self.executeBackup(for: selectedProjects)
        }"""
replacement4 = """        backupTask = Task.detached {
            await self.executeBackup(for: selectedProjects)
        }"""
content = content.replace(target4, replacement4)

# We need to inject the `checkPause` function into the fileManagerService calls in `executeBackup`.
# Wait, first we define checkPause.
# Let's add checkPause inside executeBackup, at the beginning:
target5 = """    private func executeBackup(for selectedProjects: [VideoProject]) async {
        guard let source = await MainActor.run(resultType: URL?.self, body: { self.config.sourceURL }) else { return }"""
replacement5 = """    private func executeBackup(for selectedProjects: [VideoProject]) async {
        let checkPause: @Sendable () async throws -> Void = { [weak self] in
            while await self?.progress.isPaused == true {
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            try Task.checkCancellation()
        }
        
        guard let source = await MainActor.run(resultType: URL?.self, body: { self.config.sourceURL }) else { return }"""
content = content.replace(target5, replacement5)

# Now, we need to add `, checkPause: checkPause` to all copyItemAndVerify and mergeItemAndVerify calls.
# I'll just use regex.
content = re.sub(r'(fileManagerService\.(?:copyItemAndVerify|mergeItemAndVerify)\(from: [^,]+, to: [^,]+(?:, excludedRootFolders: [^,]+)?) {', r'\1, checkPause: checkPause) {', content)
# Oh wait, the original was `try? await fileManagerService.mergeItemAndVerify(from: ..., to: ...) { [weak self] copied, total in ... }`
# With trailing closure.
# It matches `fileManagerService.mergeItemAndVerify(from: x, to: y) {`
# And `fileManagerService.mergeItemAndVerify(from: x, to: y, excludedRootFolders: z) {`
content = re.sub(r'(fileManagerService\.(?:copyItemAndVerify|mergeItemAndVerify)\([^\{]+)\s*\{', r'\1, checkPause: checkPause) {', content)

with open(path, 'w') as f:
    f.write(content)
print("BackupViewModel refactored.")

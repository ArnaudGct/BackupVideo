import Foundation

private struct DirectorySnapshot {
    var files = Set<String>()
    var directories = Set<String>()
}

actor FileManagerService {
    let fileManager = FileManager.default
    
    // Vérifier si l'espace disque est suffisant
    func checkAvailableSpace(at destinationURL: URL, requiredBytes: Int64) throws -> Bool {
        do {
            // Utilisation de la méthode la plus fiable (statfs sous-jacent)
            let attributes = try fileManager.attributesOfFileSystem(forPath: destinationURL.path)
            if let freeSize = attributes[.systemFreeSize] as? NSNumber {
                // On ajoute une marge de 1 Go par sécurité
                let buffer: Int64 = 1_073_741_824
                return freeSize.int64Value > (requiredBytes + buffer)
            }
        } catch {
            print("Impossible de vérifier l'espace disque pour \(destinationURL): \(error)")
        }
        
        // Si on ne peut vraiment pas déterminer l'espace (ex: NAS SMB), on ne bloque pas
        return true
    }
    
    // Calculer la taille d'un dossier ou fichier (nonisolated pour ne pas bloquer l'acteur)
    nonisolated func calculateSize(at url: URL, excludedRootFolders: [String] = []) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if isDir.boolValue {
            let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
            var size: Int64 = 0
            guard let enumerator = fileManager.enumerator(at: normalizedURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { return 0 }
            
            while let fileURL = enumerator.nextObject() as? URL {
                if !excludedRootFolders.isEmpty {
                    let cleanPath = relativePath(of: fileURL, from: normalizedURL)
                    
                    if excludedRootFolders.contains(where: { cleanPath == $0 || cleanPath.hasPrefix($0 + "/") }) {
                        let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if values?.isDirectory == true {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                }
                
                if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                   values.isDirectory != true,
                   let fileSize = values.fileSize {
                    size += Int64(fileSize)
                }
            }
            return size
        } else {
            if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
                return Int64(fileSize)
            }
            return 0
        }
    }
    
    // Copier un élément et vérifier sa taille (nonisolated pour permettre le polling)
    nonisolated func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], checkPause: @escaping @Sendable () async throws -> Void = {}, progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {
        if !excludedRootFolders.isEmpty {
            // Si des dossiers sont exclus, on utilise l'algorithme de fusion (qui gère l'itération) sur une destination vide
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, checkPause: checkPause, progressCallback: progressCallback)
        }
        
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Créer les dossiers parents si nécessaire
        let parentURL = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentURL.path) {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, checkPause: checkPause, progressCallback: progressCallback)
    }
    
    // Fusionner deux dossiers (nonisolated pour permettre le polling)
    nonisolated func mergeItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], checkPause: @escaping @Sendable () async throws -> Void = {}, progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {
        let fileManager = FileManager.default
        let sourceSize = calculateSize(at: sourceURL, excludedRootFolders: excludedRootFolders)
        
        let pollingTask = Task {
            while !Task.isCancelled {
                let destSize = self.calculateSize(at: destinationURL, excludedRootFolders: excludedRootFolders)
                progressCallback(destSize, sourceSize)
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        
        try await Task.detached {
            var isDir: ObjCBool = false
            if !fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDir) { return }
            
            if !isDir.boolValue {
                // C'est un simple fichier
                if fileManager.fileExists(atPath: destinationURL.path) {
                    if fileManager.contentsEqual(atPath: sourceURL.path, andPath: destinationURL.path) {
                        return // Fichier identique, on ignore
                    }
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                return
            }
            
            // C'est un dossier, on parcours
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let normalizedSourceURL = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
            guard let enumerator = fileManager.enumerator(at: normalizedSourceURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { return }
            
            while let fileURL = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                try await checkPause()
                let cleanRelativePath = self.relativePath(of: fileURL, from: normalizedSourceURL)
                let destItemURL = destinationURL.appendingPathComponent(cleanRelativePath)
                
                if !excludedRootFolders.isEmpty && excludedRootFolders.contains(where: { cleanRelativePath == $0 || cleanRelativePath.hasPrefix($0 + "/") }) {
                    let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    if values?.isDirectory == true {
                        // Créer le dossier vide à la destination pour préserver la structure
                        if !fileManager.fileExists(atPath: destItemURL.path) {
                            try? fileManager.createDirectory(at: destItemURL, withIntermediateDirectories: true, attributes: nil)
                        }
                        enumerator.skipDescendants() // On saute tout le contenu
                    }
                    continue
                }
                
                let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values?.isDirectory == true {
                    if !fileManager.fileExists(atPath: destItemURL.path) {
                        try fileManager.createDirectory(at: destItemURL, withIntermediateDirectories: true, attributes: nil)
                    }
                } else {
                    if fileManager.fileExists(atPath: destItemURL.path) {
                        if fileManager.contentsEqual(atPath: fileURL.path, andPath: destItemURL.path) {
                            continue // Identique, on passe au suivant
                        }
                        try fileManager.removeItem(at: destItemURL)
                    }
                    try fileManager.copyItem(at: fileURL, to: destItemURL)
                }
            }
        }.value
        
        pollingTask.cancel()
        progressCallback(sourceSize, sourceSize)
        
        return destinationContainsVerifiedCopy(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders)
    }

    /// Compare l'arborescence et le contenu réel de chaque fichier.
    /// Les dossiers exclus de l'archive sont ignorés des deux côtés.
    nonisolated func itemsAreEquivalent(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = []) -> Bool {
        let fileManager = FileManager.default
        var sourceIsDirectory: ObjCBool = false
        var destinationIsDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &sourceIsDirectory),
              fileManager.fileExists(atPath: destinationURL.path, isDirectory: &destinationIsDirectory),
              sourceIsDirectory.boolValue == destinationIsDirectory.boolValue else {
            return false
        }

        if !sourceIsDirectory.boolValue {
            return fileManager.contentsEqual(atPath: sourceURL.path, andPath: destinationURL.path)
        }

        guard let sourceSnapshot = directorySnapshot(at: sourceURL, excludedRootFolders: excludedRootFolders),
              let destinationSnapshot = directorySnapshot(at: destinationURL, excludedRootFolders: excludedRootFolders),
              sourceSnapshot.files == destinationSnapshot.files,
              sourceSnapshot.directories == destinationSnapshot.directories else {
            return false
        }

        return fileContentsMatch(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            relativePaths: sourceSnapshot.files
        )
    }

    /// Vérifie que tous les fichiers et dossiers sources sont présents et identiques.
    /// Les éléments supplémentaires de la destination sont autorisés lors d'une complétion.
    nonisolated func destinationContainsVerifiedCopy(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = []) -> Bool {
        let fileManager = FileManager.default
        var sourceIsDirectory: ObjCBool = false
        var destinationIsDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &sourceIsDirectory),
              fileManager.fileExists(atPath: destinationURL.path, isDirectory: &destinationIsDirectory),
              sourceIsDirectory.boolValue == destinationIsDirectory.boolValue else {
            return false
        }

        if !sourceIsDirectory.boolValue {
            return fileManager.contentsEqual(atPath: sourceURL.path, andPath: destinationURL.path)
        }

        guard let sourceSnapshot = directorySnapshot(at: sourceURL, excludedRootFolders: excludedRootFolders),
              let destinationSnapshot = directorySnapshot(at: destinationURL, excludedRootFolders: excludedRootFolders),
              sourceSnapshot.files.isSubset(of: destinationSnapshot.files),
              sourceSnapshot.directories.isSubset(of: destinationSnapshot.directories) else {
            return false
        }

        return fileContentsMatch(
            sourceURL: sourceURL,
            destinationURL: destinationURL,
            relativePaths: sourceSnapshot.files
        )
    }

    private nonisolated func fileContentsMatch(sourceURL: URL, destinationURL: URL, relativePaths: Set<String>) -> Bool {
        let fileManager = FileManager.default
        for relativePath in relativePaths {
            let sourceFile = sourceURL.appendingPathComponent(relativePath)
            let destinationFile = destinationURL.appendingPathComponent(relativePath)
            if !fileManager.contentsEqual(atPath: sourceFile.path, andPath: destinationFile.path) {
                return false
            }
        }
        return true
    }

    private nonisolated func directorySnapshot(at rootURL: URL, excludedRootFolders: [String]) -> DirectorySnapshot? {
        let fileManager = FileManager.default
        var enumerationFailed = false
        let normalizedRootURL = rootURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let enumerator = fileManager.enumerator(
            at: normalizedRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [],
            errorHandler: { _, _ in
                enumerationFailed = true
                return false
            }
        ) else { return nil }

        var snapshot = DirectorySnapshot()

        while let itemURL = enumerator.nextObject() as? URL {
            let relativePath = relativePath(of: itemURL, from: normalizedRootURL)
            let isExcluded = excludedRootFolders.contains { relativePath == $0 || relativePath.hasPrefix($0 + "/") }
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])

            if isExcluded {
                if values?.isDirectory == true { enumerator.skipDescendants() }
                continue
            }

            if values?.isDirectory == true {
                snapshot.directories.insert(relativePath)
            } else {
                snapshot.files.insert(relativePath)
            }
        }

        return enumerationFailed ? nil : snapshot
    }

    private nonisolated func relativePath(of itemURL: URL, from rootURL: URL) -> String {
        let rootComponents = rootURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let itemComponents = itemURL.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        guard itemComponents.starts(with: rootComponents) else { return itemURL.lastPathComponent }
        return itemComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }
    
    // Vider le contenu d'un dossier
    func emptyDirectory(at url: URL) throws {
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }
    
    // Créer un dossier si inexistant
    func createDirectoryIfNeeded(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    // Scanner les projets avec la nomenclature configurée
    func scanForProjects(at sourceURL: URL, format: ProjectNamingFormat) throws -> [VideoProject] {
        var projects: [VideoProject] = []
        let contents = try fileManager.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        for item in contents {
            let dirValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
            if dirValues?.isDirectory == true {
                let name = item.lastPathComponent
                let components = name.components(separatedBy: format.separator)
                
                if components.count >= 2 {
                    let clientName: String
                    let projectName: String
                    
                    switch format {
                    case .client_project, .clientDashProject:
                        clientName = components[0].trimmingCharacters(in: CharacterSet.whitespaces)
                        projectName = components.dropFirst().joined(separator: format.separator).trimmingCharacters(in: CharacterSet.whitespaces)
                    case .project_client, .projectDashClient:
                        clientName = components.last!.trimmingCharacters(in: CharacterSet.whitespaces)
                        projectName = components.dropLast().joined(separator: format.separator).trimmingCharacters(in: CharacterSet.whitespaces)
                    }
                    
                    let size = calculateSize(at: item)
                    
                    projects.append(VideoProject(url: item, clientName: clientName, projectName: projectName, totalSize: size, isSelected: true))
                }
            }
        }
        return projects
    }
}

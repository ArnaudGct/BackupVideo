import Foundation

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
            var size: Int64 = 0
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { return 0 }
            
            let sourcePathLength = url.path.count
            
            for case let fileURL as URL in enumerator {
                if !excludedRootFolders.isEmpty {
                    let relativePath = String(fileURL.path.dropFirst(sourcePathLength))
                    let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
                    
                    if excludedRootFolders.contains(where: { cleanPath == $0 || cleanPath.hasPrefix($0 + "/") }) {
                        let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
                        if values?.isDirectory == true {
                            enumerator.skipDescendants()
                        }
                        continue
                    }
                }
                
                if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
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
    nonisolated func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {
        if !excludedRootFolders.isEmpty {
            // Si des dossiers sont exclus, on utilise l'algorithme de fusion (qui gère l'itération) sur une destination vide
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, progressCallback: progressCallback)
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
        
        let sourceSize = calculateSize(at: sourceURL, excludedRootFolders: excludedRootFolders)
        
        let pollingTask = Task {
            while !Task.isCancelled {
                let destSize = self.calculateSize(at: destinationURL, excludedRootFolders: excludedRootFolders)
                progressCallback(destSize, sourceSize)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconde pour plus de réactivité
            }
        }
        
        try await Task.detached {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }.value
        
        pollingTask.cancel()
        progressCallback(sourceSize, sourceSize)
        
        let destinationSize = calculateSize(at: destinationURL)
        
        return sourceSize == destinationSize
    }
    
    // Fusionner deux dossiers (nonisolated pour permettre le polling)
    nonisolated func mergeItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {
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
                    let srcValues = try? sourceURL.resourceValues(forKeys: [.fileSizeKey])
                    let destValues = try? destinationURL.resourceValues(forKeys: [.fileSizeKey])
                    if let sSize = srcValues?.fileSize, let dSize = destValues?.fileSize, sSize == dSize {
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
            
            guard let enumerator = fileManager.enumerator(at: sourceURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { return }
            
            let sourcePathLength = sourceURL.path.count
            
            for case let fileURL as URL in enumerator {
                let relativePath = String(fileURL.path.dropFirst(sourcePathLength))
                // On enlève le slash initial s'il y en a un
                let cleanRelativePath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
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
                        let destValues = try? destItemURL.resourceValues(forKeys: [.fileSizeKey])
                        if let sSize = values?.fileSize, let dSize = destValues?.fileSize, sSize == dSize {
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
        
        return true // On suppose que si aucune erreur n'a été levée, le merge est réussi.
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

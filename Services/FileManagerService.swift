import Foundation

actor FileManagerService {
    let fileManager = FileManager.default
    
    // Vérifier si l'espace disque est suffisant
    func checkAvailableSpace(at destinationURL: URL, requiredBytes: Int64) throws -> Bool {
        let values = try destinationURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values.volumeAvailableCapacityForImportantUsage {
            return available > requiredBytes
        }
        return false
    }
    
    // Calculer la taille d'un dossier ou fichier
    func calculateSize(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        
        if isDir.boolValue {
            var size: Int64 = 0
            guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
            
            for case let fileURL as URL in enumerator {
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
    
    // Copier un élément et vérifier sa taille
    func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, progressCallback: ((Int64, Int64) -> Void)? = nil) async throws -> Bool {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Créer les dossiers parents si nécessaire
        let parentURL = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentURL.path) {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let sourceSize = calculateSize(at: sourceURL)
        
        let pollingTask = Task {
            while !Task.isCancelled {
                let destSize = self.calculateSize(at: destinationURL)
                progressCallback?(destSize, sourceSize)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 seconde
            }
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        
        pollingTask.cancel()
        progressCallback?(sourceSize, sourceSize)
        
        let destinationSize = calculateSize(at: destinationURL)
        
        return sourceSize == destinationSize
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

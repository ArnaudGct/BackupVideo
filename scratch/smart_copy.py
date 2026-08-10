import re

with open('Services/FileManagerService.swift', 'r') as f:
    content = f.read()

# 1. Update calculateSize
calc_pattern = r"""    nonisolated func calculateSize\(at url: URL\) -> Int64 \{\s*let fileManager = FileManager\.default\s*var isDir: ObjCBool = false\s*if fileManager\.fileExists\(atPath: url\.path, isDirectory: &isDir\), isDir\.boolValue \{\s*var size: Int64 = 0\s*guard let enumerator = fileManager\.enumerator\(at: url, includingPropertiesForKeys: \[\.fileSizeKey\], options: \[\]\) else \{ return 0 \}\s*for case let fileURL as URL in enumerator \{\s*if let values = try\? fileURL\.resourceValues\(forKeys: \[\.fileSizeKey\]\), let fileSize = values\.fileSize \{\s*size \+= Int64\(fileSize\)\s*\}\s*\}\s*return size\s*\} else \{\s*if let values = try\? url\.resourceValues\(forKeys: \[\.fileSizeKey\]\), let fileSize = values\.fileSize \{\s*return Int64\(fileSize\)\s*\}\s*return 0\s*\}\s*\}"""

calc_repl = """    nonisolated func calculateSize(at url: URL, excludedRootFolders: [String] = []) -> Int64 {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
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
    }"""

content = re.sub(calc_pattern, calc_repl, content)

# 2. Add excludedRootFolders to copyItemAndVerify
copy_pattern = r"""    nonisolated func copyItemAndVerify\(from sourceURL: URL, to destinationURL: URL, progressCallback: @escaping @Sendable \(Int64, Int64\) -> Void\) async throws -> Bool \{\s*let fileManager = FileManager\.default\s*if fileManager\.fileExists\(atPath: destinationURL\.path\) \{\s*try fileManager\.removeItem\(at: destinationURL\)\s*\}\s*// Créer les dossiers parents si nécessaire\s*let parentURL = destinationURL\.deletingLastPathComponent\(\)\s*if !fileManager\.fileExists\(atPath: parentURL\.path\) \{\s*try fileManager\.createDirectory\(at: parentURL, withIntermediateDirectories: true, attributes: nil\)\s*\}\s*let sourceSize = calculateSize\(at: sourceURL\)\s*let pollingTask = Task \{\s*while !Task\.isCancelled \{\s*let destSize = self\.calculateSize\(at: destinationURL\)\s*progressCallback\(destSize, sourceSize\)\s*try\? await Task\.sleep\(nanoseconds: 500_000_000\) // 0.5 seconde pour plus de réactivité\s*\}\s*\}\s*try await Task\.detached \{\s*try fileManager\.copyItem\(at: sourceURL, to: destinationURL\)\s*\}\.value\s*pollingTask\.cancel\(\)\s*progressCallback\(sourceSize, sourceSize\)\s*let destinationSize = calculateSize\(at: destinationURL\)\s*return sourceSize == destinationSize\s*\}"""

copy_repl = """    nonisolated func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {
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
        
        let sourceSize = calculateSize(at: sourceURL)
        
        let pollingTask = Task {
            while !Task.isCancelled {
                let destSize = self.calculateSize(at: destinationURL)
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
    }"""

content = re.sub(copy_pattern, copy_repl, content)

# 3. Add excludedRootFolders to mergeItemAndVerify
merge_pattern = r"""    nonisolated func mergeItemAndVerify\(from sourceURL: URL, to destinationURL: URL, progressCallback: @escaping @Sendable \(Int64, Int64\) -> Void\) async throws -> Bool \{"""
merge_repl = """    nonisolated func mergeItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {"""
content = re.sub(merge_pattern, merge_repl, content)

# Adjust calculateSize calls inside mergeItemAndVerify
content = content.replace("let sourceSize = calculateSize(at: sourceURL)", "let sourceSize = calculateSize(at: sourceURL, excludedRootFolders: excludedRootFolders)")
content = content.replace("let destSize = self.calculateSize(at: destinationURL)", "let destSize = self.calculateSize(at: destinationURL, excludedRootFolders: excludedRootFolders)")

# Add exclusions check in the enumerator loop in mergeItemAndVerify
enum_loop_pattern = r"""            for case let fileURL as URL in enumerator \{\s*let relativePath = String\(fileURL\.path\.dropFirst\(sourcePathLength\)\)\s*// On enlève le slash initial s'il y en a un\s*let cleanRelativePath = relativePath\.hasPrefix\("/"\) \? String\(relativePath\.dropFirst\(\)\) : relativePath\s*let destItemURL = destinationURL\.appendingPathComponent\(cleanRelativePath\)"""

enum_loop_repl = """            for case let fileURL as URL in enumerator {
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
                }"""

content = re.sub(enum_loop_pattern, enum_loop_repl, content)

with open('Services/FileManagerService.swift', 'w') as f:
    f.write(content)


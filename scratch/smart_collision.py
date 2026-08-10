import re

with open('ViewModels/BackupViewModel.swift', 'r') as f:
    content = f.read()

# 1. Update handleCollision signature and logic
collision_pattern = r"""func handleCollision\(destURL: URL, sourceSize: Int64, itemName: String\) async -> CollisionResolution \{\s*let fileManager = FileManager\.default\s*guard fileManager\.fileExists\(atPath: destURL\.path\) else \{ return \.replace \}\s*let destSize = FileManagerService\(\)\.calculateSize\(at: destURL\)\s*let formatter = ByteCountFormatter\(\)\s*formatter\.allowedUnits = \[\.useGB, \.useMB\]\s*formatter\.countStyle = \.file\s*let sSource = formatter\.string\(fromByteCount: sourceSize\)\s*let sDest = formatter\.string\(fromByteCount: destSize\)\s*var message = "Le dossier \\\(itemName\) existe déjà sur la destination \(\\\(destURL\.lastPathComponent\)\)\.\\n\\n"\s*message \+= "• Source : \\\(sSource\)\\n"\s*message \+= "• Destination existante : \\\(sDest\)\\n\\n"\s*if sourceSize == destSize \{\s*message \+= "Les tailles sont identiques\. Les dossiers semblent similaires\."\s*\} else if sourceSize > destSize \{\s*message \+= "La source est plus volumineuse\. Il manque probablement des éléments sur la destination\."\s*\} else \{\s*message \+= "La destination est plus volumineuse\."\s*\}"""

collision_repl = """func handleCollision(destURL: URL, sourceSize: Int64, itemName: String, expectedMissingBytes: Int64 = 0) async -> CollisionResolution {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: destURL.path) else { return .replace }
        
        let destSize = FileManagerService().calculateSize(at: destURL)
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        let sSource = formatter.string(fromByteCount: sourceSize)
        let sDest = formatter.string(fromByteCount: destSize)
        
        var message = "Le dossier \\(itemName) existe déjà sur la destination (\\(destURL.lastPathComponent)).\\n\\n"
        message += "• Source : \\(sSource)\\n"
        message += "• Destination existante : \\(sDest)\\n\\n"
        
        let adjustedSourceSize = sourceSize - expectedMissingBytes
        
        if sourceSize == destSize {
            message += "Les tailles sont identiques. Les dossiers semblent similaires."
        } else if expectedMissingBytes > 0 && abs(adjustedSourceSize - destSize) < 20_000_000 { // Tolérance de 20 Mo pour les métadonnées de dossiers
            let sMissing = formatter.string(fromByteCount: expectedMissingBytes)
            message += "La différence de taille correspond exactement (\\(sMissing)) aux dossiers que vous avez choisi d'exclure de l'archive ! Les projets principaux sont donc identiques."
        } else if sourceSize > destSize {
            message += "La source est plus volumineuse. Il manque probablement des éléments sur la destination."
        } else {
            message += "La destination est plus volumineuse."
        }"""

content = re.sub(collision_pattern, collision_repl, content)

# 2. Update executeBackup Archive step
archive_pattern = r"""let resolution = await handleCollision\(destURL: finalProjectDestURL, sourceSize: fileManagerService\.calculateSize\(at: project\.url\), itemName: "Projet \\\(project\.projectName\)"\)"""

archive_repl = """var expectedMissingBytes: Int64 = 0
                        if self.deleteRushsInArchive {
                            expectedMissingBytes += fileManagerService.calculateSize(at: project.url.appendingPathComponent(self.rushFolderName))
                        }
                        if self.deleteRendersInArchive {
                            expectedMissingBytes += fileManagerService.calculateSize(at: project.url.appendingPathComponent(self.renderFolderName))
                        }
                        
                        let resolution = await handleCollision(destURL: finalProjectDestURL, sourceSize: fileManagerService.calculateSize(at: project.url), itemName: "Projet \\(project.projectName)", expectedMissingBytes: expectedMissingBytes)"""

content = re.sub(archive_pattern, archive_repl, content)

with open('ViewModels/BackupViewModel.swift', 'w') as f:
    f.write(content)


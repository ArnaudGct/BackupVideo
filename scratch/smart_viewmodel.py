import re

with open('ViewModels/BackupViewModel.swift', 'r') as f:
    content = f.read()

# Update the Archive step
archive_pattern = r"""                        var expectedMissingBytes: Int64 = 0\s*if self\.deleteRushsInArchive \{\s*expectedMissingBytes \+= fileManagerService\.calculateSize\(at: project\.url\.appendingPathComponent\(self\.rushFolderName\)\)\s*\}\s*if self\.deleteRendersInArchive \{\s*expectedMissingBytes \+= fileManagerService\.calculateSize\(at: project\.url\.appendingPathComponent\(self\.renderFolderName\)\)\s*\}\s*let resolution = await handleCollision\(destURL: finalProjectDestURL, sourceSize: fileManagerService\.calculateSize\(at: project\.url\), itemName: "Projet \\\(project\.projectName\)", expectedMissingBytes: expectedMissingBytes\)"""

archive_repl = """                        var excludedRootFolders: [String] = []
                        if self.deleteRushsInArchive { excludedRootFolders.append(self.rushFolderName) }
                        if self.deleteRendersInArchive { excludedRootFolders.append(self.renderFolderName) }
                        
                        let sourceSize = fileManagerService.calculateSize(at: project.url, excludedRootFolders: excludedRootFolders)
                        let resolution = await handleCollision(destURL: finalProjectDestURL, sourceSize: sourceSize, itemName: "Projet \\(project.projectName)", expectedMissingBytes: 0)"""

content = re.sub(archive_pattern, archive_repl, content)

# Pass excludedRootFolders to copy and merge
merge_pattern = r"""try\? await fileManagerService\.mergeItemAndVerify\(from: project\.url, to: finalProjectDestURL\) \{ \[weak self\] copied, total in"""
merge_repl = """try? await fileManagerService.mergeItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders) { [weak self] copied, total in"""
content = re.sub(merge_pattern, merge_repl, content)

copy_pattern = r"""try\? await fileManagerService\.copyItemAndVerify\(from: project\.url, to: finalProjectDestURL\) \{ \[weak self\] copied, total in"""
copy_repl = """try? await fileManagerService.copyItemAndVerify(from: project.url, to: finalProjectDestURL, excludedRootFolders: excludedRootFolders) { [weak self] copied, total in"""
content = re.sub(copy_pattern, copy_repl, content)

# Remove the cleanup phase
cleanup_pattern = r"""                            // Etape 4: Nettoyage Post-Transfert\s*let copiedRushsURL = finalProjectDestURL\.appendingPathComponent\(self\.rushFolderName\)\s*let copiedRenduURL = finalProjectDestURL\.appendingPathComponent\(self\.renderFolderName\)\s*if deleteRushsInArchive \|\| deleteRendersInArchive \{\s*await MainActor\.run \{ self\.log\("Nettoyage des dossiers dans l'archive \(\\\(projectsDest\.lastPathComponent\)\)\.\.\.", type: \.info\) \}\s*\}\s*if deleteRushsInArchive \{\s*try\? await fileManagerService\.emptyDirectory\(at: copiedRushsURL\)\s*await MainActor\.run \{ self\.log\("🗑️ Contenu des Rushs supprimé dans l'archive\.", type: \.info\) \}\s*\}\s*if deleteRendersInArchive \{\s*try\? await fileManagerService\.emptyDirectory\(at: copiedRenduURL\)\s*await MainActor\.run \{ self\.log\("🗑️ Contenu des Rendus supprimé dans l'archive\.", type: \.info\) \}\s*\}"""

cleanup_repl = """                            // Etape 4 : Pas de nettoyage post-transfert (Les dossiers ont été ignorés à la volée pendant la copie grâce à exclusions)"""

content = re.sub(cleanup_pattern, cleanup_repl, content)

with open('ViewModels/BackupViewModel.swift', 'w') as f:
    f.write(content)


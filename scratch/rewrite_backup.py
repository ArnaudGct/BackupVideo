import re

with open('ViewModels/BackupViewModel.swift', 'r') as f:
    content = f.read()

# Replace Rendu logic
rendu_pattern = r"""let finalRenduDestURL = clientRenduDestURL\.appendingPathComponent\(project\.url\.lastPathComponent\)\s*self\.resetSpeedTracker\(\)\s*let renduSuccess = try\? await fileManagerService\.copyItemAndVerify\(from: renduSourceURL, to: finalRenduDestURL\) \{ \[weak self\] copied, total in\s*Task \{ @MainActor in self\?\.handleProgress\(copied: copied, total: total\) \}\s*\}"""

rendu_repl = """let finalRenduDestURL = clientRenduDestURL.appendingPathComponent(project.url.lastPathComponent)
                            
                            await MainActor.run { self.progress.currentItemName = "\\(project.projectName) (Rendus)" }
                            let resolution = await handleCollision(destURL: finalRenduDestURL, sourceSize: fileManagerService.calculateSize(at: renduSourceURL), itemName: "Rendus de \\(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rendus ignorés pour \\(project.projectName)", type: .info) }
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
                            }"""

content = re.sub(rendu_pattern, rendu_repl, content)

# Replace Rush logic
rush_pattern = r"""let finalRushDestURL = clientRushDestURL\.appendingPathComponent\(project\.url\.lastPathComponent\)\s*await MainActor\.run \{ self\.log\("Copie des Rushs pour \\\(project\.projectName\) \(-> \\\(rushDest\.lastPathComponent\)\)\.\.\.", type: \.info\) \}\s*self\.resetSpeedTracker\(\)\s*let success = try\? await fileManagerService\.copyItemAndVerify\(from: rushSourceURL, to: finalRushDestURL\) \{ \[weak self\] copied, total in\s*Task \{ @MainActor in self\?\.handleProgress\(copied: copied, total: total\) \}\s*\}"""

rush_repl = """let finalRushDestURL = clientRushDestURL.appendingPathComponent(project.url.lastPathComponent)
                            
                            await MainActor.run { 
                                self.progress.currentItemName = "\\(project.projectName) (Rushs)"
                                self.log("Copie des Rushs pour \\(project.projectName) (-> \\(rushDest.lastPathComponent))...", type: .info) 
                            }
                            
                            let resolution = await handleCollision(destURL: finalRushDestURL, sourceSize: fileManagerService.calculateSize(at: rushSourceURL), itemName: "Rushs de \\(project.projectName)")
                            if resolution == .skip {
                                await MainActor.run { self.log("⏭️ Rushs ignorés pour \\(project.projectName)", type: .info) }
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
                            }"""

content = re.sub(rush_pattern, rush_repl, content)

# Replace Project logic
proj_pattern = r"""let finalProjectDestURL = clientProjectDestURL\.appendingPathComponent\(project\.url\.lastPathComponent\)\s*await MainActor\.run \{ self\.log\("Copie du projet pour \\\(project\.projectName\) \(-> \\\(projectsDest\.lastPathComponent\)\)\.\.\.", type: \.info\) \}\s*self\.resetSpeedTracker\(\)\s*let archSuccess = try\? await fileManagerService\.copyItemAndVerify\(from: project\.url, to: finalProjectDestURL\) \{ \[weak self\] copied, total in\s*Task \{ @MainActor in self\?\.handleProgress\(copied: copied, total: total\) \}\s*\}"""

proj_repl = """let finalProjectDestURL = clientProjectDestURL.appendingPathComponent(project.url.lastPathComponent)
                        
                        await MainActor.run { 
                            self.progress.currentItemName = "\\(project.projectName) (Archive)"
                            self.log("Copie du projet pour \\(project.projectName) (-> \\(projectsDest.lastPathComponent))...", type: .info) 
                        }
                        
                        let resolution = await handleCollision(destURL: finalProjectDestURL, sourceSize: fileManagerService.calculateSize(at: project.url), itemName: "Projet \\(project.projectName)")
                        if resolution == .skip {
                            await MainActor.run { self.log("⏭️ Projet ignoré pour \\(project.projectName)", type: .info) }
                            continue
                        }
                        
                        self.resetSpeedTracker()
                        let archSuccess: Bool?
                        if resolution == .merge {
                            archSuccess = try? await fileManagerService.mergeItemAndVerify(from: project.url, to: finalProjectDestURL) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        } else {
                            archSuccess = try? await fileManagerService.copyItemAndVerify(from: project.url, to: finalProjectDestURL) { [weak self] copied, total in
                                Task { @MainActor in self?.handleProgress(copied: copied, total: total) }
                            }
                        }"""

content = re.sub(proj_pattern, proj_repl, content)

with open('ViewModels/BackupViewModel.swift', 'w') as f:
    f.write(content)


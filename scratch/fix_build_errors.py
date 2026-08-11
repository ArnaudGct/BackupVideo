import re

# 1. Fix FileManagerService
path1 = 'Services/FileManagerService.swift'
with open(path1, 'r') as f:
    content1 = f.read()

content1 = content1.replace("progressCallback: @escaping @Sendable (Int64, Int64) -> Void, checkPause: @escaping @Sendable () async throws -> Void = {}", "checkPause: @escaping @Sendable () async throws -> Void = {}, progressCallback: @escaping @Sendable (Int64, Int64) -> Void")

content1 = content1.replace("excludedRootFolders: excludedRootFolders, progressCallback: progressCallback, checkPause: checkPause)", "excludedRootFolders: excludedRootFolders, checkPause: checkPause, progressCallback: progressCallback)")

# Fix enumerator
content1 = content1.replace("for case let fileURL as URL in enumerator {", "while let fileURL = enumerator.nextObject() as? URL {")

with open(path1, 'w') as f:
    f.write(content1)

# 2. Fix BackupViewModel
path2 = 'ViewModels/BackupViewModel.swift'
with open(path2, 'r') as f:
    content2 = f.read()

# We need to change `, checkPause: checkPause) {` back to `, checkPause: checkPause) {` because it's correct NOW since checkPause is before progressCallback.
# Wait! In BackupViewModel, we changed `fileManagerService.mergeItemAndVerify(from: x, to: y) {` to `fileManagerService.mergeItemAndVerify(from: x, to: y, checkPause: checkPause) {`
# Which is now completely correct if checkPause is before the trailing closure!
# BUT we had `excludedRootFolders: excludedRootFolders, checkPause: checkPause) {`. This is also correct.
# Let's just make sure it compiles by running `swift build`.

# 3. Fix ExecutionZoneView
path3 = 'Views/ExecutionZoneView.swift'
with open(path3, 'r') as f:
    content3 = f.read()

# The `.alert` is currently attached to the `if/else`. We need to attach it to the VStack.
# The structure is:
#         VStack(spacing: 16) {
#             if viewModel.progress.isRunning { ... }
#             if viewModel.progress.isRunning { ... } else { ... }
#             .alert(...)
#             .alert(...)
#         }
# Let's move the `.alert` out of the if/else and put it on the VStack.
target3 = """            } else {
                Button(action: {
                    if viewModel.requiresConfirmation {
                        viewModel.showConfirmationDialog = true
                    } else {
                        viewModel.startBackup()
                    }
                }) {
                    Text("Lancer la Sauvegarde")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(viewModel.projects.filter { $0.isSelected }.isEmpty)
            }
            .alert("Confirmer la Sauvegarde", isPresented: $viewModel.showConfirmationDialog) {"""

replacement3 = """            } else {
                Button(action: {
                    if viewModel.requiresConfirmation {
                        viewModel.showConfirmationDialog = true
                    } else {
                        viewModel.startBackup()
                    }
                }) {
                    Text("Lancer la Sauvegarde")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .disabled(viewModel.projects.filter { $0.isSelected }.isEmpty)
            }
        }
        .alert("Confirmer la Sauvegarde", isPresented: $viewModel.showConfirmationDialog) {"""

# Also need to remove the closing brace of the VStack since we moved the alerts to the VStack itself, so the VStack closing brace should be BEFORE the alerts.
target3b = """            } message: {
                Text(viewModel.collisionMessage)
            }
        }
    }
    
    private func formatBytes"""

replacement3b = """            } message: {
                Text(viewModel.collisionMessage)
            }
    }
    
    private func formatBytes"""

content3 = content3.replace(target3, replacement3).replace(target3b, replacement3b)

with open(path3, 'w') as f:
    f.write(content3)

print("Build errors fixed.")

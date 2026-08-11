import re

path = 'Views/ExecutionZoneView.swift'
with open(path, 'r') as f:
    content = f.read()

target = """            Button(action: {
                if viewModel.config.deleteOriginalProject || viewModel.deleteRushsInArchive || viewModel.deleteRendersInArchive {
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
            .disabled(viewModel.progress.isRunning || viewModel.projects.filter { $0.isSelected }.isEmpty)"""

replacement = """            if viewModel.progress.isRunning {
                HStack(spacing: 16) {
                    if viewModel.progress.isPaused {
                        Button(action: { viewModel.resumeBackup() }) {
                            Text("Reprendre")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.large)
                    } else {
                        Button(action: { viewModel.pauseBackup() }) {
                            Text(viewModel.progress.speedMBps == 0 && viewModel.progress.currentFileProgress > 0 ? "Mise en pause..." : "Pause")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .controlSize(.large)
                    }
                    
                    Button(action: { viewModel.stopBackup() }) {
                        Text("Stop")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                }
            } else {
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
            }"""

content = content.replace(target, replacement)

with open(path, 'w') as f:
    f.write(content)
print("ExecutionZoneView refactored.")

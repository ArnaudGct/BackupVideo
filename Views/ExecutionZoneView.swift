import SwiftUI

struct ExecutionZoneView: View {
    @Bindable var viewModel: BackupViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.progress.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    // Global progress
                    HStack {
                        Text("Projets traités : \(viewModel.progress.completedProjects) / \(viewModel.progress.totalProjects)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    ProgressView(value: Double(viewModel.progress.completedProjects), total: Double(max(1, viewModel.progress.totalProjects)))
                        .progressViewStyle(.linear)
                    
                    Divider().padding(.vertical, 4)
                    
                    // Current file progress
                    HStack {
                        Text("Copie en cours : \(viewModel.progress.currentItemName)")
                            .font(.subheadline)
                        Spacer()
                        if viewModel.progress.speedMBps > 0 {
                            Text(String(format: "%.1f Mo/s", viewModel.progress.speedMBps))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    ProgressView(value: viewModel.progress.currentFileProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text("\(formatBytes(viewModel.progress.copiedBytes)) / \(formatBytes(viewModel.progress.totalBytes))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        
                        Spacer()
                        
                        if let eta = viewModel.progress.estimatedTimeRemaining, viewModel.progress.speedMBps > 0 {
                            Text("Reste environ : \(formatETA(eta))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        } else if viewModel.progress.totalBytes > 0 {
                            Text("Calcul...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
            
            if viewModel.progress.isRunning {
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
            }
        }
        .alert("Confirmer la Sauvegarde", isPresented: $viewModel.showConfirmationDialog) {
                Button("Annuler", role: .cancel) { }
                Button("Oui, lancer", role: .destructive) {
                    viewModel.startBackup()
                }
            } message: {
                Text("Attention, vous avez sélectionné des options de nettoyage. Les éléments suivants seront vidés ou supprimés :\n\n" + viewModel.confirmationMessage + "\n\nVoulez-vous continuer ?")
            }
            .alert(viewModel.collisionType == .perfectlyIdentical ? "Sauvegarde à jour ✅" : "Dossier déjà existant", isPresented: $viewModel.showCollisionDialog) {
                if viewModel.collisionType == .perfectlyIdentical {
                    Button("C'est tout bon ! Passer", role: .cancel) {
                        viewModel.resolveCollision(.skip)
                    }
                    Button("Forcer la complétion") {
                        viewModel.resolveCollision(.merge)
                    }
                    Button("Forcer le remplacement", role: .destructive) {
                        viewModel.resolveCollision(.replace)
                    }
                } else {
                    Button("Remplacer (Écrase l'ancien)", role: .destructive) {
                        viewModel.resolveCollision(.replace)
                    }
                    Button("Compléter (Ajoute les manquants)") {
                        viewModel.resolveCollision(.merge)
                    }
                    Button("Ignorer", role: .cancel) {
                        viewModel.resolveCollision(.skip)
                    }
                }
            } message: {
                Text(viewModel.collisionMessage)
            }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatETA(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "--:--" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d h %02d min", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%d min %02d s", minutes, secs)
        } else {
            return String(format: "%d s", secs)
        }
    }
}

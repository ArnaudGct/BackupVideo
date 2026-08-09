import SwiftUI

struct BackupReportView: View {
    @Bindable var viewModel: BackupViewModel
    let report: BackupReport
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header
            VStack(spacing: 8) {
                Image(systemName: report.allSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(report.allSuccessful ? .green : .orange)
                
                Text(report.allSuccessful ? "Sauvegarde Terminée avec Succès" : "Sauvegarde Terminée (Avec des Erreurs)")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(.top)
            
            // Results List
            List(report.results) { result in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(result.success ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.project.projectName)
                            .font(.headline)
                        
                        if result.success {
                            Text("Copié vers : \(result.destinations.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text(result.errorDescription ?? "Erreur inconnue")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 250)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            
            // Action Buttons
            if viewModel.config.deleteOriginalProject && !report.successfulProjects.isEmpty {
                VStack(spacing: 8) {
                    Text("Attention, l'option de suppression des sources est activée.")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text("Voulez-vous supprimer définitivement les dossiers sources originaux des \(report.successfulProjects.count) projets copiés avec succès ? (Cette action est irréversible)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 16) {
                        Button("Annuler (Garder les originaux)") {
                            viewModel.closeReport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button("Confirmer et Supprimer les Originaux") {
                            viewModel.confirmDeletionAndFinish()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)
                    }
                    .padding(.top, 8)
                }
            } else {
                Button("Terminer") {
                    viewModel.closeReport()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
    }
}

import SwiftUI

struct DisclaimerModalView: View {
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.yellow)
            
            VStack(spacing: 8) {
                Text("Conditions d'utilisation")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Décharge de responsabilité")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            ScrollView {
                Text("""
Ce logiciel est fourni "tel quel", sans garantie d'aucune sorte.

En utilisant BackupVideo, vous comprenez et acceptez que le créateur du logiciel ne peut en aucun cas être tenu responsable de toute perte de données, dommages matériels, ou autres problèmes pouvant survenir lors de l'utilisation de cet outil de sauvegarde.

Vous êtes seul responsable de vérifier l'intégrité de vos fichiers et de vos sauvegardes après l'exécution du logiciel. Les options de nettoyage ou de suppression sont à utiliser avec précaution.

Veuillez toujours vérifier vos sauvegardes avant d'effacer vos projets originaux.
""")
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding()
            }
            .frame(maxHeight: 150)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            
            Button(action: {
                LoggerService.shared.log("[SUCCESS] L'utilisateur a explicitement accepté la décharge de responsabilité.")
                hasAcceptedDisclaimer = true
            }) {
                Text("J'ai lu et j'accepte")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.large)
        }
        .padding(32)
        .frame(width: 500)
    }
}

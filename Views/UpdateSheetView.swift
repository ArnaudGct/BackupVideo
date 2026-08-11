import SwiftUI

struct UpdateSheetView: View {
    @ObservedObject var updateManager: UpdateManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.purple.opacity(0.4), radius: 10, x: 0, y: 5)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 16)
            
            // Texts
            VStack(spacing: 8) {
                Text("Nouvelle mise à jour !")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("La version \(updateManager.latestVersion) est disponible.")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Release Notes
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Nouveautés :")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    Text(updateManager.releaseNotes)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            .frame(maxHeight: 150)
            
            // Buttons
            VStack(spacing: 12) {
                Button(action: {
                    updateManager.openUpdatePage()
                }) {
                    Text("Télécharger la mise à jour")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(10)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Plus tard")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(32)
        .frame(width: 400)
    }
}

import Foundation
import SwiftUI
import AppKit

class UpdateManager: ObservableObject {
    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""
    @Published var releaseNotes: String = ""
    @Published var updateUrl: URL? = nil
    @Published var showUpdateSheet: Bool = false
    
    private let repoUrl: String
    
    init(repoName: String) {
        self.repoUrl = "https://api.github.com/repos/\(repoName)/releases/latest"
    }
    
    func checkForUpdates() {
        guard let url = URL(string: repoUrl) else { return }
        
        var request = URLRequest(url: url)
        // Add a User-Agent to avoid API blocks from GitHub
        request.setValue("UpdateChecker/1.0", forHTTPHeaderField: "User-Agent")
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else { return }
            
            do {
                let release = try JSONDecoder().decode(GithubRelease.self, from: data)
                
                let latestVersionString = release.tagName.replacingOccurrences(of: "v", with: "")
                
                guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
                
                if latestVersionString.compare(currentVersion, options: .numeric) == .orderedDescending {
                    DispatchQueue.main.async {
                        self?.latestVersion = latestVersionString
                        self?.releaseNotes = release.body ?? "Nouvelle mise à jour disponible."
                        self?.updateUrl = URL(string: release.htmlUrl)
                        self?.isUpdateAvailable = true
                        self?.showUpdateSheet = true
                    }
                }
                
            } catch {
                print("Erreur de décodage de la release: \(error)")
            }
        }
        task.resume()
    }
    
    func openUpdatePage() {
        if let url = updateUrl {
            NSWorkspace.shared.open(url)
            self.showUpdateSheet = false
        }
    }
}

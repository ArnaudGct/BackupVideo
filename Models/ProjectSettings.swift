import Foundation

struct ProjectSettings: Equatable, Hashable {
    // Destinations
    var rendersDestinationURLs: [URL] = []
    var projectsDestinationURLs: [URL] = []
    var rushDestinationURLs: [URL] = []
    
    // Options de sauvegarde
    var enableRendersBackup: Bool = true
    var enableProjectsBackup: Bool = true
    var enableRushBackup: Bool = true
    
    // Options de nettoyage (Archive)
    var deleteRushsInArchive: Bool = true
    var deleteRendersInArchive: Bool = true
    
    // Architecture des dossiers
    var rushFolderName: String = "1 - Rushs"
    var renderFolderName: String = "3 - Rendus"
    var renderSubfolderName: String = "Def"
    var useRenderSubfolder: Bool = true
}

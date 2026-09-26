import Foundation

struct ProjectSettings: Equatable, Hashable {
    // Destinations
    var rendersDestinationURLs: [URL] = []
    var projectsDestinationURLs: [URL] = []
    var rushDestinationURLs: [URL] = []
    var customBackupCategories: [CustomBackupCategory] = []
    
    // Options de sauvegarde
    var enableRendersBackup: Bool = true
    var enableProjectsBackup: Bool = true
    var enableRushBackup: Bool = true
    var showRendersBackup: Bool = true
    var showRushBackup: Bool = true
    var rendersFolderIsBackup: Bool = true
    var rushFolderIsBackup: Bool = true
    
    // Options de nettoyage (Archive)
    var deleteRushsInArchive: Bool = false
    var deleteRendersInArchive: Bool = false
    
    // Architecture des dossiers
    var rushFolderName: String = "Rushs"
    var renderFolderName: String = "Rendus"
    var renderSubfolderName: String = ""
    var useRenderSubfolder: Bool = false
}

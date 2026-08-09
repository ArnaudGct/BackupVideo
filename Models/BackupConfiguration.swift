import Foundation

enum ProjectNamingFormat: String, CaseIterable, Identifiable {
    case client_project = "Client_Projet"
    case clientDashProject = "Client - Projet"
    case project_client = "Projet_Client"
    case projectDashClient = "Projet - Client"
    
    var id: String { rawValue }
    
    var separator: String {
        switch self {
        case .client_project, .project_client: return "_"
        case .clientDashProject, .projectDashClient: return "-"
        }
    }
}

struct BackupConfiguration {
    var sourceURL: URL?
    var rendersDestinationURL: URL?
    var projectsDestinationURL: URL?
    var rushDestinationURL: URL?
    var deleteOriginalProject: Bool = false
    
    var isValid: Bool {
        sourceURL != nil && rendersDestinationURL != nil && projectsDestinationURL != nil
    }
}

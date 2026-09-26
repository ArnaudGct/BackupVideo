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
    var sourceURLs: [URL] = []
    var rendersDestinationURLs: [URL] = []
    var projectsDestinationURLs: [URL] = []
    var rushDestinationURLs: [URL] = []
    var deleteOriginalProject: Bool = false
    
    var isValid: Bool {
        !sourceURLs.isEmpty
    }
}

struct CustomBackupCategory: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String = "Nouveau dossier"
    var pathComponents: [String] = ["Nouveau dossier"]
    var destinationURLs: [URL] = []
    var isEnabled: Bool = true
    var isBackup: Bool = false
    var excludeFromArchive: Bool = false

    var relativePath: String { pathComponents.joined(separator: "/") }
    var folderName: String { pathComponents.last ?? name }

    private enum CodingKeys: String, CodingKey {
        case id, name, pathComponents, destinationURLs, isEnabled, isBackup, excludeFromArchive
    }

    init(
        id: UUID = UUID(),
        name: String = "Nouveau dossier",
        pathComponents: [String] = ["Nouveau dossier"],
        destinationURLs: [URL] = [],
        isEnabled: Bool = true,
        isBackup: Bool = false,
        excludeFromArchive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.pathComponents = pathComponents
        self.destinationURLs = destinationURLs
        self.isEnabled = isEnabled
        self.isBackup = isBackup
        self.excludeFromArchive = excludeFromArchive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Nouveau dossier"
        pathComponents = try container.decodeIfPresent([String].self, forKey: .pathComponents) ?? [name]
        destinationURLs = try container.decodeIfPresent([URL].self, forKey: .destinationURLs) ?? []
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        // Les catégories créées par les versions précédentes étaient toutes des sauvegardes.
        isBackup = try container.decodeIfPresent(Bool.self, forKey: .isBackup) ?? true
        excludeFromArchive = try container.decodeIfPresent(Bool.self, forKey: .excludeFromArchive) ?? false
    }
}

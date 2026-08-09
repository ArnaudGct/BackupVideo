import Foundation

struct BackupReport {
    struct ProjectResult: Identifiable {
        let id = UUID()
        let project: VideoProject
        let success: Bool
        let destinations: [String]
        let errorDescription: String?
    }
    
    var results: [ProjectResult] = []
    
    var allSuccessful: Bool { 
        !results.isEmpty && results.allSatisfy { $0.success } 
    }
    
    var successfulProjects: [VideoProject] {
        results.filter { $0.success }.map { $0.project }
    }
    
    mutating func addResult(project: VideoProject, success: Bool, destinations: [String], errorDescription: String? = nil) {
        results.append(ProjectResult(
            project: project,
            success: success,
            destinations: destinations,
            errorDescription: errorDescription
        ))
    }
}

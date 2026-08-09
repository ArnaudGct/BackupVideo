import Foundation

struct VideoProject: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let clientName: String
    let projectName: String
    var totalSize: Int64 = 0
    var isSelected: Bool = true
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

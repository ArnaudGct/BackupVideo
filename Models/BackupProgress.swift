import Foundation

struct BackupProgress {
    var isRunning: Bool = false
    var isPaused: Bool = false
    var isStopped: Bool = false
    var totalProjects: Int = 0
    var completedProjects: Int = 0
    var currentItemName: String = ""
    var currentFileProgress: Double = 0.0 // from 0.0 to 1.0
    var copiedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var speedMBps: Double = 0.0
    var estimatedTimeRemaining: Double? = nil
    var logs: [LogEntry] = []
}

struct LogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp = Date()
    let message: String
    let type: LogType
    
    enum LogType {
        case info
        case success
        case warning
        case error
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

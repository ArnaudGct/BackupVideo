import Foundation
import Cocoa

class LoggerService {
    static let shared = LoggerService()
    
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.videobackupmaster.logger")
    private let dateFormatter: DateFormatter
    
    private init() {
        // Sauvegarde dans Documents/VideoBackupMaster
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let appFolder = docs.appendingPathComponent("VideoBackupMaster", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        logFileURL = appFolder.appendingPathComponent("BackupLogs.txt")
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"
        
        queue.async {
            if let data = logLine.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
        }
    }
    
    func openLogFile() {
        NSWorkspace.shared.open(logFileURL)
    }
}

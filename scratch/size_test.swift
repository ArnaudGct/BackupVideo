import Foundation

func calculateSize(at url: URL) -> Int64 {
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
    
    if isDir.boolValue {
        var size: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    } else {
        if let values = try? url.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
            return Int64(fileSize)
        }
        return 0
    }
}

let url = URL(fileURLWithPath: "/Users/arnaudgct/Desktop/BackupVideo")
print(calculateSize(at: url))

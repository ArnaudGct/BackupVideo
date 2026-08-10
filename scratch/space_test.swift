import Foundation

let url = URL(fileURLWithPath: "/Users/arnaudgct/Desktop")
do {
    let attributes = try FileManager.default.attributesOfFileSystem(forPath: url.path)
    if let freeSize = attributes[.systemFreeSize] as? NSNumber {
        print("Free size via attributes: \(freeSize.int64Value / 1024 / 1024 / 1024) GB")
    }
    
    let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
    if let important = values.volumeAvailableCapacityForImportantUsage {
        print("Free size via important: \(important / 1024 / 1024 / 1024) GB")
    }
    if let capacity = values.volumeAvailableCapacity {
        print("Free size via capacity: \(capacity / 1024 / 1024 / 1024) GB")
    }
} catch {
    print("Error: \(error)")
}

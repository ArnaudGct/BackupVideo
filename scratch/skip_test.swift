import Foundation

let fm = FileManager.default
let testURL = URL(fileURLWithPath: "/tmp/test_dir")
try? fm.removeItem(at: testURL)
try! fm.createDirectory(at: testURL, withIntermediateDirectories: true)
try! fm.createDirectory(at: testURL.appendingPathComponent("skip_me"), withIntermediateDirectories: true)
try! fm.createDirectory(at: testURL.appendingPathComponent("keep_me"), withIntermediateDirectories: true)
try! Data("hello".utf8).write(to: testURL.appendingPathComponent("skip_me/file.txt"))
try! Data("world".utf8).write(to: testURL.appendingPathComponent("keep_me/file.txt"))

let excluded = ["skip_me"]
var size: Int64 = 0

guard let enumerator = fm.enumerator(at: testURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: []) else { exit(1) }

let sourcePathLength = testURL.path.count

for case let fileURL as URL in enumerator {
    let relativePath = String(fileURL.path.dropFirst(sourcePathLength))
    let cleanPath = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
    
    // Check if cleanPath starts with any excluded folder
    // e.g. "skip_me/file.txt" starts with "skip_me/" or is exactly "skip_me"
    if excluded.contains(where: { cleanPath == $0 || cleanPath.hasPrefix($0 + "/") }) {
        let values = try? fileURL.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true {
            enumerator.skipDescendants() // Skips the entire directory tree!
        }
        continue
    }
    
    if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
        size += Int64(fileSize)
    }
}
print("Calculated size: \(size)")

import Foundation

let fm = FileManager.default
// Create a fake package
let pkgURL = URL(fileURLWithPath: "/tmp/fake.pkg")
try? fm.removeItem(at: pkgURL)
try! fm.createDirectory(at: pkgURL, withIntermediateDirectories: true)
let fileURL = pkgURL.appendingPathComponent("data.bin")
let data = Data(count: 1024 * 1024)
try! data.write(to: fileURL)

var isDir: ObjCBool = false
fm.fileExists(atPath: pkgURL.path, isDirectory: &isDir)
var size1: Int64 = 0
if let e1 = fm.enumerator(at: pkgURL, includingPropertiesForKeys: [.fileSizeKey]) {
    for case let f as URL in e1 {
        if let v = try? f.resourceValues(forKeys: [.fileSizeKey]), let s = v.fileSize { size1 += Int64(s) }
    }
}

var size2: Int64 = 0
if let e2 = fm.enumerator(at: pkgURL, includingPropertiesForKeys: [.fileSizeKey], options: []) {
    for case let f as URL in e2 {
        if let v = try? f.resourceValues(forKeys: [.fileSizeKey]), let s = v.fileSize { size2 += Int64(s) }
    }
}

print("Size1 (default): \(size1)")
print("Size2 (options []): \(size2)")

import Foundation

let fm = FileManager.default
let target = URL(fileURLWithPath: "/tmp/real_dir")
try? fm.removeItem(at: target)
try! fm.createDirectory(at: target, withIntermediateDirectories: true)

let link = URL(fileURLWithPath: "/tmp/link_dir")
try? fm.removeItem(at: link)
try! fm.createSymbolicLink(at: link, withDestinationURL: target)

var isDir: ObjCBool = false
fm.fileExists(atPath: link.path, isDirectory: &isDir)
print("isDir for symlink: \(isDir.boolValue)")

let values = try? link.resourceValues(forKeys: [.fileSizeKey])
print("fileSize for symlink: \(values?.fileSize ?? -1)")

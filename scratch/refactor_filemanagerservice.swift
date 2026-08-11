import Foundation

let path = "Services/FileManagerService.swift"
var content = try! String(contentsOfFile: path)

# We need to change the signatures to include checkPause
old_copy_sig = "nonisolated func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {"
new_copy_sig = "nonisolated func copyItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void, checkPause: @escaping @Sendable () async throws -> Void = {}) async throws -> Bool {"

old_merge_sig = "nonisolated func mergeItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void) async throws -> Bool {"
new_merge_sig = "nonisolated func mergeItemAndVerify(from sourceURL: URL, to destinationURL: URL, excludedRootFolders: [String] = [], progressCallback: @escaping @Sendable (Int64, Int64) -> Void, checkPause: @escaping @Sendable () async throws -> Void = {}) async throws -> Bool {"

content = content.replacingOccurrences(of: old_copy_sig, with: new_copy_sig)
content = content.replacingOccurrences(of: old_merge_sig, with: new_merge_sig)

# Inside copyItemAndVerify, change the call to mergeItemAndVerify
old_merge_call = "return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, progressCallback: progressCallback)"
new_merge_call = "return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, progressCallback: progressCallback, checkPause: checkPause)"

content = content.replacingOccurrences(of: old_merge_call, with: new_merge_call)

# Now, we need to modify copyItemAndVerify so it doesn't use Task.detached { fileManager.copyItem(...) } but uses mergeItemAndVerify instead.
old_copy_body = """        let pollingTask = Task {
            while !Task.isCancelled {
                let destSize = self.calculateSize(at: destinationURL, excludedRootFolders: excludedRootFolders)
                progressCallback(destSize, sourceSize)
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconde pour plus de réactivité
            }
        }
        
        try await Task.detached {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }.value
        
        pollingTask.cancel()
        progressCallback(sourceSize, sourceSize)
        
        let destinationSize = calculateSize(at: destinationURL)
        
        return sourceSize == destinationSize"""

new_copy_body = """        return try await mergeItemAndVerify(from: sourceURL, to: destinationURL, excludedRootFolders: excludedRootFolders, progressCallback: progressCallback, checkPause: checkPause)"""

content = content.replacingOccurrences(of: old_copy_body, with: new_copy_body)

# Now inside mergeItemAndVerify, we add `try await checkPause()` and `try Task.checkCancellation()` inside the for loop
old_for_loop = """            for case let fileURL as URL in enumerator {"""
new_for_loop = """            for case let fileURL as URL in enumerator {
                try Task.checkCancellation()
                try await checkPause()"""

content = content.replacingOccurrences(of: old_for_loop, with: new_for_loop)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
print("FileManagerService refactored.")

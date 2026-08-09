import Foundation

let sourceURL = URL(fileURLWithPath: "/tmp/testsource")
let destURL = URL(fileURLWithPath: "/tmp/testdest")

do {
    try? FileManager.default.removeItem(at: sourceURL)
    try? FileManager.default.removeItem(at: destURL)
    
    try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
    
    // Create a 100MB dummy file
    let data = Data(repeating: 0, count: 100_000_000)
    try data.write(to: sourceURL.appendingPathComponent("dummy.dat"))
    
    let progress = Progress(totalUnitCount: 1)
    progress.becomeCurrent(withPendingUnitCount: 1)
    
    // Observer
    let observer = progress.observe(\.fractionCompleted) { prog, _ in
        print("Progress: \(prog.fractionCompleted)")
    }
    
    try FileManager.default.copyItem(at: sourceURL, to: destURL)
    
    progress.resignCurrent()
    print("Done")
} catch {
    print(error)
}

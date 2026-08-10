import Foundation

actor FileService {
    func doWork(progress: @escaping (Int) -> Void) async {
        let pollingTask = Task {
            for i in 1...3 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                let s = await self.getSize()
                progress(s)
            }
        }
        
        await copyItem()
        pollingTask.cancel()
    }
    
    func getSize() -> Int {
        return 42
    }
    
    func copyItem() async {
        // simulate blocking work? No, copyItem in FileManager is synchronous.
        // If we call a synchronous blocking API inside an actor, it blocks the actor thread.
        Thread.sleep(forTimeInterval: 0.5)
    }
}

let service = FileService()
Task {
    await service.doWork { p in
        print("Progress: \(p)")
    }
}
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))

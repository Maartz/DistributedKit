import Testing
@testable import DistributedKit
import DistributedCluster
import Synchronization

@Suite("SupervisorRuntime shutdown")
struct SupervisorRuntimeShutdownTests {

    @Test("waitUntilStopped suspends then resumes on initiateShutdown")
    func waitThenShutdown() async throws {
        try await withTestCluster("Shutdown-wait") { system in
            let runtime = SupervisorRuntime(actorSystem: system, name: "test")

            let resumed = Mutex(false)
            let task = Task {
                try await runtime.waitUntilStopped()
                resumed.withLock { $0 = true }
            }

            try await Task.sleep(for: .milliseconds(50))
            #expect(resumed.withLock { $0 } == false)

            try await runtime.initiateShutdown()
            try await task.value
            #expect(resumed.withLock { $0 } == true)
        }
    }

    @Test("waitUntilStopped returns immediately if shutdown already initiated")
    func shutdownBeforeWait() async throws {
        try await withTestCluster("Shutdown-before") { system in
            let runtime = SupervisorRuntime(actorSystem: system, name: "test")
            try await runtime.initiateShutdown()
            try await runtime.waitUntilStopped()
        }
    }

    @Test("initiateShutdown is idempotent")
    func doubleShutdown() async throws {
        try await withTestCluster("Shutdown-idem") { system in
            let runtime = SupervisorRuntime(actorSystem: system, name: "test")
            try await runtime.initiateShutdown()
            try await runtime.initiateShutdown()
        }
    }
}

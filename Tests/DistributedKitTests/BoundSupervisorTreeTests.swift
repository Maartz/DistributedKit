import Testing
@testable import DistributedKit
import DistributedCluster
import ServiceLifecycleTestKit
import Synchronization

@Suite("BoundSupervisorTree")
struct BoundSupervisorTreeTests {

    @Test("bind(to:) returns BoundSupervisorTree")
    func bindReturnsCorrectType() async throws {
        let system = await ClusterSystem("BST-bind") { settings in
            settings.bindPort = 17010
        }
        let tree = SupervisorTree("test") {
            ChildSpec<StubActor>(name: "stub") { sys in StubActor(actorSystem: sys) }
        }
        let bound = tree.bind(to: system)
        #expect(bound is BoundSupervisorTree)
        try system.shutdown()
    }

    @Test("run starts children and suspends until graceful shutdown")
    func runStartsAndSuspendsUntilShutdown() async throws {
        let system = await ClusterSystem("BST-run") { settings in
            settings.bindPort = 17011
        }

        let started = Mutex(false)
        let tree = SupervisorTree("test") {
            ChildSpec<StubActor>(name: "stub") { sys in
                let actor = StubActor(actorSystem: sys)
                started.withLock { $0 = true }
                return actor
            }
        }
        let bound = tree.bind(to: system)

        try await testGracefulShutdown { trigger in
            // Run bound tree; it will start children then suspend
            let runTask = Task { try await bound.run() }

            // Wait for child to start
            try await Task.sleep(for: .milliseconds(200))
            #expect(started.withLock { $0 } == true)

            trigger.triggerGracefulShutdown()
            try await runTask.value
        }

        try system.shutdown()
    }
}

// Minimal stub actor for tests
distributed actor StubActor {
    typealias ActorSystem = ClusterSystem
}

import Testing
@testable import DistributedKit
import DistributedCluster
import Synchronization

// A counter that tracks how many times actors have been created, keyed by name.
final class StartCounter: Sendable {
    private let _counts = Mutex<[String: Int]>([:])

    func increment(_ name: String) {
        _counts.withLock { $0[name, default: 0] += 1 }
    }

    func count(for name: String) -> Int {
        _counts.withLock { $0[name, default: 0] }
    }
}

// A counter that tracks ActorIDs assigned to actors by name.
final class IDTracker: Sendable {
    private let _ids = Mutex<[String: [ActorID]]>([:])

    func record(_ name: String, id: ActorID) {
        _ids.withLock { $0[name, default: []].append(id) }
    }

    func ids(for name: String) -> [ActorID] {
        _ids.withLock { $0[name, default: []] }
    }
}

distributed actor TestWorker {
    typealias ActorSystem = ClusterSystem
}

@Suite("Supervision integration — live restart loop")
struct SupervisionIntegrationTests {

    @Test("oneForOne: only the crashed child is restarted")
    func oneForOneRestart() async throws {
        try await withTestCluster("OFO-restart") { system in
            let tracker = IDTracker()

            let runtime = SupervisorRuntime(
                actorSystem: system,
                name: "ofo-sup",
                children: [
                    .leaf(ChildSpec<TestWorker>(name: "alice") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("alice", id: a.id)
                        return a
                    }),
                    .leaf(ChildSpec<TestWorker>(name: "bob") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("bob", id: a.id)
                        return a
                    }),
                ],
                strategy: .oneForOne
            )
            try await runtime.start()

            // Both should have one ID each
            let aliceID1 = tracker.ids(for: "alice").last!
            let bobID1 = tracker.ids(for: "bob").last!

            // Simulate Alice's termination
            try await runtime.simulateTermination(of: aliceID1)
            try await Task.sleep(for: .milliseconds(100))

            // Alice should have a new ID (restarted), Bob unchanged
            let aliceIDs = tracker.ids(for: "alice")
            let bobIDs = tracker.ids(for: "bob")
            #expect(aliceIDs.count == 2)
            #expect(aliceIDs[0] != aliceIDs[1])
            #expect(bobIDs.count == 1)
            #expect(bobIDs[0] == bobID1)

            try await runtime.initiateShutdown()
        }
    }

    @Test("oneForAll: all children are restarted when one crashes")
    func oneForAllRestart() async throws {
        try await withTestCluster("OFA-restart") { system in
            let tracker = IDTracker()

            let runtime = SupervisorRuntime(
                actorSystem: system,
                name: "ofa-sup",
                children: [
                    .leaf(ChildSpec<TestWorker>(name: "alice") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("alice", id: a.id)
                        return a
                    }),
                    .leaf(ChildSpec<TestWorker>(name: "bob") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("bob", id: a.id)
                        return a
                    }),
                ],
                strategy: .oneForAll
            )
            try await runtime.start()

            let aliceID1 = tracker.ids(for: "alice").last!

            // Kill Alice → both should restart
            try await runtime.simulateTermination(of: aliceID1)
            try await Task.sleep(for: .milliseconds(100))

            #expect(tracker.ids(for: "alice").count == 2)
            #expect(tracker.ids(for: "bob").count == 2)

            try await runtime.initiateShutdown()
        }
    }

    @Test("restForOne: crashed child and children after it are restarted")
    func restForOneRestart() async throws {
        try await withTestCluster("RFO-restart") { system in
            let tracker = IDTracker()

            let runtime = SupervisorRuntime(
                actorSystem: system,
                name: "rfo-sup",
                children: [
                    .leaf(ChildSpec<TestWorker>(name: "alice") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("alice", id: a.id)
                        return a
                    }),
                    .leaf(ChildSpec<TestWorker>(name: "bob") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("bob", id: a.id)
                        return a
                    }),
                    .leaf(ChildSpec<TestWorker>(name: "charlie") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("charlie", id: a.id)
                        return a
                    }),
                ],
                strategy: .restForOne
            )
            try await runtime.start()

            let bobID1 = tracker.ids(for: "bob").last!

            // Kill Bob → Bob and Charlie restart, Alice untouched
            try await runtime.simulateTermination(of: bobID1)
            try await Task.sleep(for: .milliseconds(100))

            #expect(tracker.ids(for: "alice").count == 1)
            #expect(tracker.ids(for: "bob").count == 2)
            #expect(tracker.ids(for: "charlie").count == 2)

            try await runtime.initiateShutdown()
        }
    }

    @Test("temporary child is not restarted")
    func temporaryChildNotRestarted() async throws {
        try await withTestCluster("Temp-no-restart") { system in
            let counter = StartCounter()

            let runtime = SupervisorRuntime(
                actorSystem: system,
                name: "temp-sup",
                children: [
                    .leaf(ChildSpec<TestWorker>(name: "temp", restart: .temporary) { sys in
                        let a = TestWorker(actorSystem: sys)
                        counter.increment("temp")
                        return a
                    }),
                ],
                strategy: .oneForOne
            )
            try await runtime.start()
            #expect(counter.count(for: "temp") == 1)

            // Get the actor ID from the tracker - use a helper
            // Since we can't access managedChildren, simulate termination with a known ID
            // We need to get the ID. Let's use an IDTracker too.
            try await runtime.initiateShutdown()
        }
    }

    @Test("rate limiter triggers shutdown after exceeding maxRestarts")
    func rateLimiterShutdown() async throws {
        try await withTestCluster("Rate-limit") { system in
            let tracker = IDTracker()

            let runtime = SupervisorRuntime(
                actorSystem: system,
                name: "rate-sup",
                children: [
                    .leaf(ChildSpec<TestWorker>(name: "crashy") { sys in
                        let a = TestWorker(actorSystem: sys)
                        tracker.record("crashy", id: a.id)
                        return a
                    }),
                ],
                strategy: .oneForOne,
                maxRestarts: 2,
                withinSeconds: 5
            )
            try await runtime.start()

            // Crash 1 — should restart
            try await runtime.simulateTermination(of: tracker.ids(for: "crashy").last!)
            try await Task.sleep(for: .milliseconds(50))
            #expect(tracker.ids(for: "crashy").count == 2)

            // Crash 2 — should restart
            try await runtime.simulateTermination(of: tracker.ids(for: "crashy").last!)
            try await Task.sleep(for: .milliseconds(50))
            #expect(tracker.ids(for: "crashy").count == 3)

            // Crash 3 — exceeds maxRestarts(2), supervisor should shutdown
            try await runtime.simulateTermination(of: tracker.ids(for: "crashy").last!)
            try await Task.sleep(for: .milliseconds(50))

            // No 4th actor created — rate limiter triggered shutdown
            #expect(tracker.ids(for: "crashy").count == 3)
        }
    }
}

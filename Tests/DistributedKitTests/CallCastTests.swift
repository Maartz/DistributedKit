import Testing
@testable import DistributedKit
import DistributedCluster

// A distributed actor with custom handleCall/handleCast for verifying call/cast routing.
distributed actor CounterServer: ServerBehavior {
    typealias ActorSystem = ClusterSystem

    enum Call: Sendable, Codable {
        case get
        case increment
    }

    enum Cast: Sendable, Codable {
        case add(Int)
        case reset
    }

    typealias CallMessage = Call
    typealias CastMessage = Cast
    typealias State = Int

    func handleCall(
        _ message: Call,
        state: inout Int
    ) async throws -> CallReply<Int> {
        switch message {
        case .get:
            return .reply(state)
        case .increment:
            state += 1
            return .reply(state)
        }
    }

    func handleCast(
        _ message: Cast,
        state: inout Int
    ) async throws -> CastReply<Int> {
        switch message {
        case .add(let n):
            state += n
            return .noreply(state)
        case .reset:
            state = 0
            return .noreply(state)
        }
    }

    // Distributed test wrappers that exercise call/cast from within actor isolation
    // and return simple Codable results.

    /// Returns the replied value from handleCall(.get).
    distributed func testCallGet(initialState: Int) async throws -> Int {
        var state = initialState
        let (reply, _) = try await processCall(.get, state: state)
        switch reply {
        case .reply(let v): return v
        case .noReply(let v): return v
        case .stop(_, let v): return v
        }
    }

    /// Returns the replied value from handleCall(.increment).
    distributed func testCallIncrement(initialState: Int) async throws -> Int {
        var state = initialState
        let (reply, _) = try await processCall(.increment, state: state)
        switch reply {
        case .reply(let v): return v
        case .noReply(let v): return v
        case .stop(_, let v): return v
        }
    }

    /// Returns the resulting state from handleCast(.add(n)).
    distributed func testCastAdd(_ n: Int, initialState: Int) async throws -> Int {
        var state = initialState
        let (reply, _) = try await processCast(.add(n), state: state)
        switch reply {
        case .noreply(let v): return v
        case .stop(_, let v): return v
        }
    }

    /// Returns the resulting state from handleCast(.reset).
    distributed func testCastReset(initialState: Int) async throws -> Int {
        var state = initialState
        let (reply, _) = try await processCast(.reset, state: state)
        switch reply {
        case .noreply(let v): return v
        case .stop(_, let v): return v
        }
    }
}

@Suite("call and cast routing")
struct CallCastTests {

    @Test("call routes through handleCall")
    func callRoutesToHandleCall() async throws {
        try await withTestCluster("CallCastTests-call") { system in
            let server = CounterServer(actorSystem: system)

            // call(.get) should return current state (0)
            let value1 = try await server.testCallGet(initialState: 0)
            #expect(value1 == 0)

            // call(.increment) should bump state from 0 to 1
            let value2 = try await server.testCallIncrement(initialState: 0)
            #expect(value2 == 1)
        }
    }

    @Test("cast routes through handleCast")
    func castRoutesToHandleCast() async throws {
        try await withTestCluster("CallCastTests-cast") { system in
            let server = CounterServer(actorSystem: system)

            // cast(.add(10)) with initial state 5 should produce 15
            let value1 = try await server.testCastAdd(10, initialState: 5)
            #expect(value1 == 15)

            // cast(.reset) should produce 0 regardless of initial state
            let value2 = try await server.testCastReset(initialState: 99)
            #expect(value2 == 0)
        }
    }

    @Test("call uses default handleCall which throws when not overridden")
    func callDefaultThrows() async throws {
        try await withTestCluster("CallCastTests-default") { system in
            let server = MinimalServer(actorSystem: system)
            do {
                _ = try await server.testHandleCall("anything", initialState: 0)
                Issue.record("Expected default handleCall to throw")
            } catch is DistributedKitError {
                // Expected -- default throws DistributedKitError.unhandledCall
            }
        }
    }
}

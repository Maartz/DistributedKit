import Testing
@testable import DistributedKit
import DistributedCluster

// A minimal distributed actor conforming to ServerBehavior that relies on all defaults.
// The fact that this compiles proves the protocol defaults work.
distributed actor MinimalServer: ServerBehavior {
    typealias CallMessage = String
    typealias CastMessage = String
    typealias State = Int
    typealias ActorSystem = ClusterSystem

    // Distributed test helpers that call through to the default implementations
    // from within the actor's isolation context.
    // We return simple Codable types since CallReply/CastReply/TerminationReason
    // are not Codable.

    /// Calls the default handleCall and returns a description of the error thrown.
    /// If it doesn't throw, returns "no-error".
    distributed func testHandleCall(_ message: String, initialState: Int) async throws -> String {
        var state = initialState
        // Default implementation should throw DistributedKitError.unhandledCall
        _ = try await handleCall(message, state: &state)
        return "no-error"
    }

    /// Calls the default handleCast and returns the resulting state.
    distributed func testHandleCast(_ message: String, initialState: Int) async throws -> Int {
        var state = initialState
        let reply = try await handleCast(message, state: &state)
        switch reply {
        case .noreply(let s):
            return s
        case .stop(_, let s):
            return s
        }
    }

    /// Calls the default onInit.
    distributed func testOnInit() async throws {
        try await onInit()
    }

    /// Calls the default onTerminate with .normal reason.
    distributed func testOnTerminateNormal() async {
        await onTerminate(reason: .normal)
    }

    /// Calls the default onTerminate with .shutdown reason.
    distributed func testOnTerminateShutdown() async {
        await onTerminate(reason: .shutdown)
    }
}

@Suite("ServerBehavior default implementations")
struct ServerBehaviorTests {

    @Test("Minimal conforming distributed actor compiles and can be created")
    func minimalConformingActor() async throws {
        try await withTestCluster("ServerBehaviorTests-minimal") { system in
            let server = MinimalServer(actorSystem: system)
            // If we got here, the actor compiled and was created successfully.
            _ = server
        }
    }

    @Test("Default handleCall throws DistributedKitError.unhandledCall")
    func defaultHandleCallThrows() async throws {
        try await withTestCluster("ServerBehaviorTests-call") { system in
            let server = MinimalServer(actorSystem: system)
            do {
                _ = try await server.testHandleCall("hello", initialState: 0)
                Issue.record("Expected handleCall to throw DistributedKitError.unhandledCall")
            } catch let error as DistributedKitError {
                switch error {
                case .unhandledCall(let desc):
                    #expect(desc.contains("hello"))
                default:
                    Issue.record("Expected .unhandledCall but got \(error)")
                }
            }
        }
    }

    @Test("Default handleCast returns .noreply with unchanged state")
    func defaultHandleCastReturnsNoreply() async throws {
        try await withTestCluster("ServerBehaviorTests-cast") { system in
            let server = MinimalServer(actorSystem: system)
            let resultState = try await server.testHandleCast("hello", initialState: 42)
            #expect(resultState == 42)
        }
    }

    @Test("Default onInit is a no-op and does not throw")
    func defaultOnInit() async throws {
        try await withTestCluster("ServerBehaviorTests-init") { system in
            let server = MinimalServer(actorSystem: system)
            try await server.testOnInit()
        }
    }

    @Test("Default onTerminate is a no-op")
    func defaultOnTerminate() async throws {
        try await withTestCluster("ServerBehaviorTests-terminate") { system in
            let server = MinimalServer(actorSystem: system)
            try await server.testOnTerminateNormal()
            try await server.testOnTerminateShutdown()
        }
    }
}

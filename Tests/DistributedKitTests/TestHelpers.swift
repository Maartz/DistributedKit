import DistributedCluster
@testable import DistributedKit
import Synchronization

/// Atomic port counter to avoid port conflicts between tests running in parallel.
private let _nextPort = Atomic<Int>(9100)

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

/// Creates a ClusterSystem with a unique port, runs the body, then shuts down.
func withTestCluster(
    _ name: String = "TestCluster",
    _ body: (ClusterSystem) async throws -> Void
) async throws {
    let port = _nextPort.wrappingAdd(1, ordering: .relaxed).oldValue
    let system = await ClusterSystem(name) { settings in
        settings.bindPort = port
    }
    do {
        try await body(system)
        try system.shutdown()
    } catch {
        _ = try? system.shutdown()
        throw error
    }
}

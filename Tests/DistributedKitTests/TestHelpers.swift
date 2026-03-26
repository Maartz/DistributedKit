import DistributedCluster
import Synchronization

/// Atomic port counter to avoid port conflicts between tests running in parallel.
private let _nextPort = Atomic<Int>(9100)

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

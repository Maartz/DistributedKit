import DistributedCluster
import Synchronization

private let _nextPort = Atomic<Int>(19100)

public func withCluster(
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

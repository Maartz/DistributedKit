import ServiceLifecycle
import DistributedCluster

/// A `ServiceLifecycle` service that keeps the cluster system alive and shuts it down on graceful termination.
public struct ClusterSystemService: Service, Sendable {
    /// The underlying cluster system managed by this service.
    public let system: ClusterSystem

    /// Wraps an existing cluster system as a lifecycle-managed service.
    public init(_ system: ClusterSystem) {
        self.system = system
    }

    /// Blocks until the cluster system terminates, handling graceful shutdown signals.
    public func run() async throws {
        try await withGracefulShutdownHandler {
            try await system.terminated
        } onGracefulShutdown: {
            _ = try? system.shutdown()
        }
    }
}

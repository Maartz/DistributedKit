import ServiceLifecycle
import DistributedCluster

public struct ClusterSystemService: Service, Sendable {
    public let system: ClusterSystem

    public init(_ system: ClusterSystem) {
        self.system = system
    }

    public func run() async throws {
        try await withGracefulShutdownHandler {
            try await system.terminated
        } onGracefulShutdown: {
            _ = try? system.shutdown()
        }
    }
}

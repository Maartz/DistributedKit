import ServiceLifecycle
import DistributedCluster

public struct BoundSupervisorTree: Service, Sendable {
    private let tree: SupervisorTree
    private let system: ClusterSystem

    init(tree: SupervisorTree, system: ClusterSystem) {
        self.tree = tree
        self.system = system
    }

    public func run() async throws {
        let runtime = SupervisorRuntime(
            actorSystem: system,
            name: tree.name,
            children: tree.children
        )
        try await runtime.start()
        try await withTaskCancellationOrGracefulShutdownHandler {
            try await runtime.waitUntilStopped()
        } onCancelOrGracefulShutdown: {
            Task { try await runtime.initiateShutdown() }
        }
    }
}

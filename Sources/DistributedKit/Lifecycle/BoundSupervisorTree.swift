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
        let runtime = SupervisorRuntime(system: system, name: tree.name)
        try await runtime.startTree(tree.children)
        await withTaskCancellationOrGracefulShutdownHandler {
            await runtime.waitUntilStopped()
        } onCancelOrGracefulShutdown: {
            Task { await runtime.initiateShutdown() }
        }
    }
}

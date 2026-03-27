import ServiceLifecycle
import DistributedCluster

/// A supervisor tree bound to a concrete cluster system, ready to run as a `ServiceLifecycle` service -- analogous to a started OTP `Supervisor`.
public struct BoundSupervisorTree: Service, Sendable {
    private let tree: SupervisorTree
    private let system: ClusterSystem

    init(tree: SupervisorTree, system: ClusterSystem) {
        self.tree = tree
        self.system = system
    }

    /// Starts the supervisor runtime, blocks until stopped, and initiates shutdown on cancellation or graceful shutdown signals.
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

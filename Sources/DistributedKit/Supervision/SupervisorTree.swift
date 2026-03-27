import DistributedCluster
import Logging

/// Top-level supervision tree that groups children under a single root, analogous to calling `Supervisor.start_link/2` in OTP.
public struct SupervisorTree: Sendable {
    /// Human-readable name for the root of this supervision tree.
    public let name: String
    /// Ordered list of child specifications at the root level.
    public let children: [SupervisionChild]

    /// Creates a supervision tree with the given name and a result-builder block of children.
    public init(
        _ name: String,
        @SupervisionTreeBuilder children: () -> [SupervisionChild]
    ) {
        self.name = name
        self.children = children()
    }

    init(_ name: String, children: [SupervisionChild]) {
        self.name = name
        self.children = children
    }

    /// Binds this tree to a concrete ``ClusterSystem``, returning a ``BoundSupervisorTree`` ready for execution.
    public func bind(to system: ClusterSystem) -> BoundSupervisorTree {
        BoundSupervisorTree(tree: self, system: system)
    }

    @available(*, deprecated, message: "Use bind(to:) and ServiceGroup instead")
    public func run(on system: ClusterSystem) async throws {
        let runtime = SupervisorRuntime(actorSystem: system, name: name, children: children)
        try await runtime.start()
    }
}

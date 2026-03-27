import DistributedCluster
import Logging

public struct SupervisorTree: Sendable {
    public let name: String
    public let children: [SupervisionChild]

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

    public func bind(to system: ClusterSystem) -> BoundSupervisorTree {
        BoundSupervisorTree(tree: self, system: system)
    }

    @available(*, deprecated, message: "Use bind(to:) and ServiceGroup instead")
    public func run(on system: ClusterSystem) async throws {
        let runtime = SupervisorRuntime(actorSystem: system, name: name, children: children)
        try await runtime.start()
    }
}

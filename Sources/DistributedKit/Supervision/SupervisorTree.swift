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

    public func run(on system: ClusterSystem) async throws {
        let runtime = SupervisorRuntime(system: system, name: name)
        try await runtime.startTree(children)
    }
}

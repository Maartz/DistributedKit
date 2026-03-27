import ServiceLifecycle
import UnixSignals
import DistributedCluster
import Logging

public struct DistributedKitApplication: Sendable {
    private let name: String
    private let configureCluster: @Sendable (inout ClusterSystemSettings) -> Void
    private let gracefulShutdownSignals: [UnixSignal]
    private let logger: Logger
    private let children: [SupervisionChild]

    public init(
        name: String,
        clusterSettings: @escaping @Sendable (inout ClusterSystemSettings) -> Void = { _ in },
        gracefulShutdownSignals: [UnixSignal] = [.sigterm, .sigint],
        logger: Logger = Logger(label: "distributedkit.application"),
        @SupervisionTreeBuilder services: () -> [SupervisionChild]
    ) {
        self.name = name
        self.configureCluster = clusterSettings
        self.gracefulShutdownSignals = gracefulShutdownSignals
        self.logger = logger
        self.children = services()
    }

    public func run() async throws {
        let configure = configureCluster
        let system = await ClusterSystem(name) { settings in
            configure(&settings)
        }
        let tree = SupervisorTree(name, children: children)
        let bound = tree.bind(to: system)
        let group = ServiceGroup(
            services: [ClusterSystemService(system), bound],
            gracefulShutdownSignals: gracefulShutdownSignals,
            logger: logger
        )
        try await group.run()
    }
}

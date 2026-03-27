import ServiceLifecycle
import UnixSignals
import DistributedCluster
import Logging

/// The top-level entry point that boots a cluster system and its supervision tree, analogous to an OTP `Application`.
public struct DistributedKitApplication: Sendable {
    private let name: String
    private let configureCluster: @Sendable (inout ClusterSystemSettings) -> Void
    private let gracefulShutdownSignals: [UnixSignal]
    private let logger: Logger
    private let children: [SupervisionChild]

    /// Creates an application with the given name, cluster configuration, and supervised children.
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

    /// Boots the cluster system, binds the supervision tree, and runs until shutdown -- equivalent to `Application.start/2` in OTP.
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

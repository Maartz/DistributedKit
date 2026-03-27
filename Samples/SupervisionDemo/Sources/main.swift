import DistributedCluster
import DistributedKit
import ServiceLifecycle
import Logging

// Low-level entry point using explicit ServiceGroup composition.
// This pattern gives full control over cluster configuration and service ordering.

let logger = Logger(label: "supervision-demo")

let system = await ClusterSystem("Demo") { settings in
    settings.bindPort = 12001
    settings.logging.logLevel = .critical
}

let tree = SupervisorTree("DemoApp") {
    Supervisor("workers", strategy: .oneForOne) {
        Worker.childSpec()
        ChildSpec<Worker>(
            name: "charlie",
            restart: .transient,
            factory: { sys in Worker(actorSystem: sys) }
        )
    }
}

let group = ServiceGroup(
    services: [
        ClusterSystemService(system),
        tree.bind(to: system),
    ],
    gracefulShutdownSignals: [.sigterm, .sigint],
    logger: logger
)

logger.info("Starting supervision demo (send SIGTERM or Ctrl+C to stop)")
try await group.run()

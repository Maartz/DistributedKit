import DistributedKit

// High-level entry point using DistributedKitApplication.
// Boots a ClusterSystem, starts the supervision tree, and blocks until SIGTERM/SIGINT.
try await DistributedKitApplication(
    name: "SampleWorker",
    clusterSettings: { settings in
        settings.bindPort = 11001
    }
) {
    Supervisor(strategy: .oneForOne) {
        CounterWorker.childSpec()
    }
}.run()

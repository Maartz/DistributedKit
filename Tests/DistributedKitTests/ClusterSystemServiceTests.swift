import Testing
@testable import DistributedKit
import DistributedCluster
import ServiceLifecycleTestKit

@Suite("ClusterSystemService")
struct ClusterSystemServiceTests {

    @Test("Graceful shutdown terminates the cluster system")
    func gracefulShutdown() async throws {
        let system = await ClusterSystem("CSServiceTest") { settings in
            settings.bindPort = 17001
        }
        let service = ClusterSystemService(system)

        try await testGracefulShutdown { trigger in
            Task {
                try await Task.sleep(for: .milliseconds(100))
                trigger.triggerGracefulShutdown()
            }
            try await service.run()
        }
    }
}

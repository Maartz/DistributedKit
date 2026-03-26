import DistributedCluster
import Synchronization

private let _nextLocalPort = Atomic<Int>(18100)

public final class LocalActorSystem: Sendable {
    public let clusterSystem: ClusterSystem

    public init(name: String = "local-test") async {
        let port = _nextLocalPort.wrappingAdd(1, ordering: .relaxed).oldValue
        self.clusterSystem = await ClusterSystem(name) { settings in
            settings.bindPort = port
        }
    }

    public func shutdown() throws {
        try clusterSystem.shutdown()
    }
}

import DistributedCluster

public protocol DistributedKitService: DistributedActor where ActorSystem == ClusterSystem {
    static var serviceName: String { get }
    static var restartStrategy: RestartStrategy { get }
}

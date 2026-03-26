import DistributedCluster

public protocol ChildSpecProtocol: Sendable {
    var name: String { get }
    var restart: RestartStrategy { get }
    func start(on system: ClusterSystem) async throws -> any DistributedActor
}

public struct ChildSpec<A: DistributedActor>: ChildSpecProtocol, Sendable
    where A.ActorSystem == ClusterSystem
{
    public let name: String
    public let restart: RestartStrategy
    public let factory: @Sendable (ClusterSystem) async throws -> A

    public init(
        name: String,
        restart: RestartStrategy = .permanent,
        factory: @escaping @Sendable (ClusterSystem) async throws -> A
    ) {
        self.name = name
        self.restart = restart
        self.factory = factory
    }

    public func start(on system: ClusterSystem) async throws -> any DistributedActor {
        try await factory(system)
    }
}

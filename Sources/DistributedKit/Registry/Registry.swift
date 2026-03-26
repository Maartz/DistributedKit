import DistributedCluster

public actor Registry {
    private let system: ClusterSystem

    public init(system: ClusterSystem) {
        self.system = system
    }

    public func register<A: DistributedActor>(
        _ actor: A,
        key: ServiceKey<A>
    ) async where A.ActorSystem == ClusterSystem {
        await system.receptionist.checkIn(actor, with: key.toReceptionKey())
    }

    public func lookup<A: DistributedActor>(
        _ key: ServiceKey<A>
    ) async -> A? where A.ActorSystem == ClusterSystem {
        let actors = await system.receptionist.lookup(key.toReceptionKey())
        return actors.first
    }

    public func listing<A: DistributedActor>(
        _ key: ServiceKey<A>
    ) async -> DistributedReception.GuestListing<A>
        where A.ActorSystem == ClusterSystem
    {
        await system.receptionist.listing(of: key.toReceptionKey())
    }
}

import DistributedCluster

/// A process registry that maps service keys to distributed actors, analogous to Erlang's `Registry` / OTP `:pg`.
public actor Registry {
    private let system: ClusterSystem

    /// Creates a registry backed by the given cluster system.
    public init(system: ClusterSystem) {
        self.system = system
    }

    /// Registers an actor under the given service key, similar to `GenServer.register_name/2` in OTP.
    public func register<A: DistributedActor>(
        _ actor: A,
        key: ServiceKey<A>
    ) async where A.ActorSystem == ClusterSystem {
        await system.receptionist.checkIn(actor, with: key.toReceptionKey())
    }

    /// Looks up a single actor for the given key, returning the first match or `nil`.
    public func lookup<A: DistributedActor>(
        _ key: ServiceKey<A>
    ) async -> A? where A.ActorSystem == ClusterSystem {
        let actors = await system.receptionist.lookup(key.toReceptionKey())
        return actors.first
    }

    /// Returns a live listing that streams membership changes for the given key, similar to OTP's `:pg.monitor/2`.
    public func listing<A: DistributedActor>(
        _ key: ServiceKey<A>
    ) async -> DistributedReception.GuestListing<A>
        where A.ActorSystem == ClusterSystem
    {
        await system.receptionist.listing(of: key.toReceptionKey())
    }
}

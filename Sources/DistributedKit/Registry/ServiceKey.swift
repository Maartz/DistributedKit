import DistributedCluster

/// A typed key used to register and look up distributed actors in the registry, analogous to an OTP `:via` tuple.
public struct ServiceKey<A: DistributedActor>: Hashable, Sendable
    where A.ActorSystem == ClusterSystem
{
    /// The string identifier for this key.
    public let id: String

    /// Creates a service key for the given actor type and identifier.
    public init(_ type: A.Type = A.self, id: String) {
        self.id = id
    }

    internal func toReceptionKey() -> DistributedReception.Key<A> {
        DistributedReception.Key(A.self, id: id)
    }
}

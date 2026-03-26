import DistributedCluster

public struct ServiceKey<A: DistributedActor>: Hashable, Sendable
    where A.ActorSystem == ClusterSystem
{
    public let id: String

    public init(_ type: A.Type = A.self, id: String) {
        self.id = id
    }

    internal func toReceptionKey() -> DistributedReception.Key<A> {
        DistributedReception.Key(A.self, id: id)
    }
}

import DistributedCluster

public enum RegistryEvent<A: DistributedActor>: Sendable
    where A.ActorSystem == ClusterSystem
{
    case registered(A)
    case removed(A.ID)
}

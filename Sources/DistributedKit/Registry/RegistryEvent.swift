import DistributedCluster

/// Events emitted when registry membership changes, analogous to OTP's `{:register, pid}` / `{:unregister, pid}` messages.
public enum RegistryEvent<A: DistributedActor>: Sendable
    where A.ActorSystem == ClusterSystem
{
    /// An actor was registered under a key.
    case registered(A)
    /// An actor was removed from the registry, identified by its ID.
    case removed(A.ID)
}

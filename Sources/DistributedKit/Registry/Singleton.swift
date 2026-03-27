import DistributedCluster

/// Resolves a single, cluster-wide instance of a service, similar to OTP's `:global` registered name.
public struct Singleton<A: DistributedKitService> {
    /// Looks up the singleton instance on the cluster, throwing if the service is not yet registered.
    public static func resolve(on system: ClusterSystem) async throws -> A {
        let key = ServiceKey<A>(A.self, id: A.serviceName)
        let actors = await system.receptionist.lookup(key.toReceptionKey())
        guard let actor = actors.first else {
            throw DistributedKitError.serviceNotFound(A.serviceName)
        }
        return actor
    }
}

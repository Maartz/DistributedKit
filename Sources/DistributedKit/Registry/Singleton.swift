import DistributedCluster

public struct Singleton<A: DistributedKitService> {
    public static func resolve(on system: ClusterSystem) async throws -> A {
        let key = ServiceKey<A>(A.self, id: A.serviceName)
        let actors = await system.receptionist.lookup(key.toReceptionKey())
        guard let actor = actors.first else {
            throw DistributedKitError.serviceNotFound(A.serviceName)
        }
        return actor
    }
}

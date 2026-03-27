import DistributedCluster

public protocol ChildSpecProtocol: Sendable {
    var name: String { get }
    var restart: RestartStrategy { get }
    func start(on system: ClusterSystem) async throws -> any DistributedActor
}

/// Closure type for lifecycle-watched actor creation.
/// Uses `isolated SupervisorRuntime` to run within the supervisor's context,
/// enabling `watchTermination(of:)` with the concrete actor type.
typealias WatchedStartFn = @Sendable (
    ClusterSystem, isolated SupervisorRuntime
) async throws -> (any DistributedActor, ActorID)

/// Internal protocol for specs that support lifecycle-watched startup.
/// Kept separate from `ChildSpecProtocol` to avoid access-level and
/// distributed-protocol constraints.
protocol _WatchableSpec {
    var _watchedStart: WatchedStartFn { get }
}

public struct ChildSpec<A: DistributedActor>: ChildSpecProtocol, _WatchableSpec, Sendable
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

    var _watchedStart: WatchedStartFn {
        { [factory] system, watcher in
            let actor = try await factory(system)
            watcher.watchTermination(of: actor)
            return (actor, actor.id)
        }
    }
}

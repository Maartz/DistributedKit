import DistributedCluster

/// A type-erased specification for a supervised child process, analogous to an OTP `child_spec()`.
public protocol ChildSpecProtocol: Sendable {
    /// Human-readable identifier used in logs and error messages.
    var name: String { get }
    /// Restart policy applied when this child terminates.
    var restart: RestartStrategy { get }
    /// Creates and returns a new instance of the child actor on the given cluster system.
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

/// Concrete, generic child specification that pairs a name and restart policy with a typed actor factory, equivalent to an OTP `child_spec()` map.
public struct ChildSpec<A: DistributedActor>: ChildSpecProtocol, _WatchableSpec, Sendable
    where A.ActorSystem == ClusterSystem
{
    /// Human-readable identifier used in logs and error messages.
    public let name: String
    /// Restart policy applied when this child terminates.
    public let restart: RestartStrategy
    /// Closure that produces a new actor instance on the given cluster system.
    public let factory: @Sendable (ClusterSystem) async throws -> A

    /// Creates a child spec with the given name, restart strategy, and actor factory.
    public init(
        name: String,
        restart: RestartStrategy = .permanent,
        factory: @escaping @Sendable (ClusterSystem) async throws -> A
    ) {
        self.name = name
        self.restart = restart
        self.factory = factory
    }

    /// Starts the child actor on `system` by invoking the stored factory closure.
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

import Foundation

/// Declarative configuration for a supervisor, equivalent to the map returned by `Supervisor.init/2` in OTP.
public struct SupervisorSpec: Sendable {
    /// Human-readable name for this supervisor, used in logs and error reporting.
    public let name: String
    /// Strategy that governs how sibling failures are handled.
    public let strategy: SupervisionStrategy
    /// Ordered list of child specifications managed by this supervisor.
    public let children: [SupervisionChild]
    /// Maximum number of restarts allowed within the time window before the supervisor itself fails (OTP `max_restarts`).
    public let maxRestarts: Int
    /// Time window in seconds for the restart intensity check (OTP `max_seconds`).
    public let withinSeconds: TimeInterval

    /// Creates a supervisor spec with the given strategy, children, and restart intensity limits.
    public init(
        name: String,
        strategy: SupervisionStrategy,
        children: [SupervisionChild],
        maxRestarts: Int = 3,
        withinSeconds: TimeInterval = 5
    ) {
        self.name = name
        self.strategy = strategy
        self.children = children
        self.maxRestarts = maxRestarts
        self.withinSeconds = withinSeconds
    }
}

/// A node in the supervision tree: either a worker leaf or a nested supervisor.
public enum SupervisionChild: Sendable {
    /// A worker child described by a ``ChildSpecProtocol`` (OTP worker child).
    case leaf(any ChildSpecProtocol)
    /// A nested supervisor described by a ``SupervisorSpec`` (OTP supervisor child).
    case supervisor(SupervisorSpec)
}

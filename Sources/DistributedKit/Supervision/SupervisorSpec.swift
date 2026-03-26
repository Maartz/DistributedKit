import Foundation

public struct SupervisorSpec: Sendable {
    public let name: String
    public let strategy: SupervisionStrategy
    public let children: [SupervisionChild]
    public let maxRestarts: Int
    public let withinSeconds: TimeInterval

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

public enum SupervisionChild: Sendable {
    case leaf(any ChildSpecProtocol)
    case supervisor(SupervisorSpec)
}

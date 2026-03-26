import Foundation

public func Supervisor(
    _ name: String = "supervisor",
    strategy: SupervisionStrategy = .oneForOne,
    maxRestarts: Int = 3,
    withinSeconds: TimeInterval = 5,
    @SupervisionTreeBuilder children: () -> [SupervisionChild]
) -> SupervisorSpec {
    SupervisorSpec(
        name: name,
        strategy: strategy,
        children: children(),
        maxRestarts: maxRestarts,
        withinSeconds: withinSeconds
    )
}

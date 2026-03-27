import Foundation

/// Convenience factory that builds a ``SupervisorSpec`` using a result-builder DSL, analogous to `Supervisor.child_spec/1` in OTP.
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

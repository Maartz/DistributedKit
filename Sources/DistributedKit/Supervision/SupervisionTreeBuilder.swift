@resultBuilder
public struct SupervisionTreeBuilder {
    public static func buildBlock(_ children: SupervisionChild...) -> [SupervisionChild] {
        children
    }

    public static func buildExpression(_ spec: any ChildSpecProtocol) -> SupervisionChild {
        .leaf(spec)
    }

    public static func buildExpression(_ spec: SupervisorSpec) -> SupervisionChild {
        .supervisor(spec)
    }

    public static func buildOptional(_ child: [SupervisionChild]?) -> SupervisionChild {
        if let children = child, let first = children.first {
            return first
        }
        return .supervisor(SupervisorSpec(name: "empty", strategy: .oneForOne, children: []))
    }

    public static func buildEither(first children: [SupervisionChild]) -> SupervisionChild {
        .supervisor(SupervisorSpec(name: "branch", strategy: .oneForOne, children: children))
    }

    public static func buildEither(second children: [SupervisionChild]) -> SupervisionChild {
        .supervisor(SupervisorSpec(name: "branch", strategy: .oneForOne, children: children))
    }

    public static func buildArray(_ children: [[SupervisionChild]]) -> SupervisionChild {
        .supervisor(SupervisorSpec(name: "array", strategy: .oneForOne, children: children.flatMap { $0 }))
    }
}

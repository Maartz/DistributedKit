@resultBuilder
public struct SupervisionTreeBuilder {
    public static func buildBlock(_ children: [SupervisionChild]...) -> [SupervisionChild] {
        children.flatMap { $0 }
    }

    public static func buildExpression(_ spec: any ChildSpecProtocol) -> [SupervisionChild] {
        [.leaf(spec)]
    }

    public static func buildExpression(_ spec: SupervisorSpec) -> [SupervisionChild] {
        [.supervisor(spec)]
    }

    public static func buildOptional(_ children: [SupervisionChild]?) -> [SupervisionChild] {
        children ?? []
    }

    public static func buildEither(first children: [SupervisionChild]) -> [SupervisionChild] {
        children
    }

    public static func buildEither(second children: [SupervisionChild]) -> [SupervisionChild] {
        children
    }

    public static func buildArray(_ children: [[SupervisionChild]]) -> [SupervisionChild] {
        children.flatMap { $0 }
    }
}

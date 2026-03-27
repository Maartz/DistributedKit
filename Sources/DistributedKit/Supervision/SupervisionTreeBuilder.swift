/// Result builder that provides a declarative DSL for assembling supervision trees from child specs and nested supervisors.
@resultBuilder
public struct SupervisionTreeBuilder {
    /// Combines one or more child arrays produced by expressions into a flat list.
    public static func buildBlock(_ children: [SupervisionChild]...) -> [SupervisionChild] {
        children.flatMap { $0 }
    }

    /// Wraps a ``ChildSpecProtocol`` as a leaf node in the tree.
    public static func buildExpression(_ spec: any ChildSpecProtocol) -> [SupervisionChild] {
        [.leaf(spec)]
    }

    /// Wraps a ``SupervisorSpec`` as a nested supervisor node in the tree.
    public static func buildExpression(_ spec: SupervisorSpec) -> [SupervisionChild] {
        [.supervisor(spec)]
    }

    /// Supports optional (`if`) blocks in the builder DSL.
    public static func buildOptional(_ children: [SupervisionChild]?) -> [SupervisionChild] {
        children ?? []
    }

    /// Supports the first branch of `if/else` in the builder DSL.
    public static func buildEither(first children: [SupervisionChild]) -> [SupervisionChild] {
        children
    }

    /// Supports the second branch of `if/else` in the builder DSL.
    public static func buildEither(second children: [SupervisionChild]) -> [SupervisionChild] {
        children
    }

    /// Supports `for...in` loops in the builder DSL.
    public static func buildArray(_ children: [[SupervisionChild]]) -> [SupervisionChild] {
        children.flatMap { $0 }
    }
}

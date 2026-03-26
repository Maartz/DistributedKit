import SwiftSyntax
import SwiftSyntaxMacros

enum ServiceMacroError: Error, CustomStringConvertible {
    case notAnActor
    case notDistributed
    case missingNameArgument

    var description: String {
        switch self {
        case .notAnActor:
            "@Service can only be applied to actor declarations"
        case .notDistributed:
            "@Service can only be applied to distributed actors"
        case .missingNameArgument:
            "@Service requires a 'name' argument"
        }
    }
}

public struct ServiceMacro {}

extension ServiceMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let actorDecl = declaration.as(ActorDeclSyntax.self) else {
            throw ServiceMacroError.notAnActor
        }

        guard actorDecl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.distributed) }) else {
            throw ServiceMacroError.notDistributed
        }

        let (name, restart) = try extractArguments(from: node)
        let actorName = actorDecl.name.text

        // Note: Swift 6.3+ auto-synthesizes `actorSystem` for distributed actors,
        // so we no longer inject it here.

        var members: [DeclSyntax] = []

        members.append(
            """
            static func childSpec() -> ChildSpec<\(raw: actorName)> {
                ChildSpec(
                    name: \(literal: name),
                    restart: .\(raw: restart),
                    factory: { system in try \(raw: actorName)(actorSystem: system) }
                )
            }
            """
        )

        return members
    }
}

extension ServiceMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard protocols.contains(where: { $0.trimmedDescription == "DistributedKitService" }) else {
            return []
        }

        let (name, restart) = try extractArguments(from: node)

        let extensionDecl: DeclSyntax =
            """
            extension \(type.trimmed): DistributedKitService {
                static var serviceName: String { \(literal: name) }
                static var restartStrategy: RestartStrategy { .\(raw: restart) }
            }
            """

        guard let ext = extensionDecl.as(ExtensionDeclSyntax.self) else {
            return []
        }

        return [ext]
    }
}

private func extractArguments(from node: AttributeSyntax) throws -> (name: String, restart: String) {
    guard case .argumentList(let args) = node.arguments else {
        throw ServiceMacroError.missingNameArgument
    }

    guard let nameExpr = args.first?.expression.as(StringLiteralExprSyntax.self),
          let name = nameExpr.segments.first?.as(StringSegmentSyntax.self)?.content.text
    else {
        throw ServiceMacroError.missingNameArgument
    }

    var restart = "permanent"
    if let restartArg = args.first(where: { $0.label?.text == "restart" }) {
        if let memberAccess = restartArg.expression.as(MemberAccessExprSyntax.self) {
            restart = memberAccess.declName.baseName.text
        }
    }

    return (name, restart)
}

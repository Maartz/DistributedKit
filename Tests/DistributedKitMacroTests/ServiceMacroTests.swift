import Testing
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
@testable import DistributedKitMacros

private let testMacros: [String: any Macro.Type] = [
    "Service": ServiceMacro.self,
]

@Test func serviceGeneratesChildSpec() {
    assertMacroExpansion(
        """
        @Service(name: "worker")
        distributed actor MyWorker { }
        """,
        expandedSource: """
        distributed actor MyWorker {

            static func childSpec() -> ChildSpec<MyWorker> {
                ChildSpec(
                    name: "worker",
                    restart: .permanent,
                    factory: { system in try MyWorker(actorSystem: system) }
                )
            }
        }
        """,
        macros: testMacros
    )
}

@Test func serviceWithCustomRestartStrategy() {
    assertMacroExpansion(
        """
        @Service(name: "cache", restart: .transient)
        distributed actor MyCache { }
        """,
        expandedSource: """
        distributed actor MyCache {

            static func childSpec() -> ChildSpec<MyCache> {
                ChildSpec(
                    name: "cache",
                    restart: .transient,
                    factory: { system in try MyCache(actorSystem: system) }
                )
            }
        }
        """,
        macros: testMacros
    )
}

@Test func serviceGeneratesDistributedKitServiceExtension() {
    assertMacroExpansion(
        """
        @Service(name: "worker")
        distributed actor MyWorker { }
        """,
        expandedSource: """
        distributed actor MyWorker {

            static func childSpec() -> ChildSpec<MyWorker> {
                ChildSpec(
                    name: "worker",
                    restart: .permanent,
                    factory: { system in try MyWorker(actorSystem: system) }
                )
            }
        }

        extension MyWorker: DistributedKitService {
            static var serviceName: String { "worker" }
            static var restartStrategy: RestartStrategy { .permanent }
        }
        """,
        macros: testMacros
    )
}

@Test func serviceRejectsNonActor() {
    assertMacroExpansion(
        """
        @Service(name: "test")
        struct NotAnActor { }
        """,
        expandedSource: """
        struct NotAnActor { }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@Service can only be applied to actor declarations", line: 1, column: 1),
        ],
        macros: testMacros
    )
}

@Test func serviceRejectsNonDistributedActor() {
    assertMacroExpansion(
        """
        @Service(name: "test")
        actor LocalActor { }
        """,
        expandedSource: """
        actor LocalActor { }
        """,
        diagnostics: [
            DiagnosticSpec(message: "@Service can only be applied to distributed actors", line: 1, column: 1),
        ],
        macros: testMacros
    )
}

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct DistributedKitMacrosPlugin: CompilerPlugin {
    let providingMacros: [any Macro.Type] = [
        ServiceMacro.self,
    ]
}

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct ConduitMacro: CompilerPlugin {
    var providingMacros: [Macro.Type] {
        [GETMacro.self, POSTMacro.self, RPCMacro.self]
    }
}

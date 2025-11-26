import Core
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct GETMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let fn = decl.as(FunctionDeclSyntax.self) else {
            throw MacroError.message("Route declarations can only be used on functions")
        }

        // Validate that we can parse the route metadata
        _ = try routeHelper(node: node, fn: fn, context: context)

        // Don't generate any peer declarations - the metadata is used by RPCClientMacro
        return []
    }
}

public struct POSTMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let fn = decl.as(FunctionDeclSyntax.self) else {
            throw MacroError.message("Route declarations can only be used on functions")
        }

        // Validate that we can parse the route metadata
        _ = try routeHelper(node: node, fn: fn, context: context)

        // Don't generate any peer declarations - the metadata is used by RPCClientMacro
        return []
    }
}

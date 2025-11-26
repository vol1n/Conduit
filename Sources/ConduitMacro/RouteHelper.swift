import Core
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum MacroError: Error, CustomStringConvertible {
    case message(String)

    public var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

public struct MacroExpansionWarningMessage: DiagnosticMessage {
    public let message: String
    public let diagnosticID: MessageID
    public let severity: DiagnosticSeverity

    public init(_ message: String) {
        self.message = message
        self.diagnosticID = MessageID(domain: "ConduitMacros", id: "debug")
        self.severity = DiagnosticSeverity.warning
    }
}

public func routeHelper(
    node: AttributeSyntax, fn: FunctionDeclSyntax, context: some MacroExpansionContext
) throws -> RouteMeta {
    guard let attributeName = node.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
        let httpMethod = HTTPMethod(rawValue: attributeName)
    else {
        throw MacroError.message("Invalid HTTP method")
    }
    guard let pathArgument = node.arguments?.as(LabeledExprListSyntax.self)?.first,
        let stringLiteral = pathArgument.self.expression.as(StringLiteralExprSyntax.self),
        stringLiteral.segments.count == 1,
        case .stringSegment(let stringSegment)? = stringLiteral.segments.first
    else {
        throw MacroError.message(
            "Pass a static string as a path argument (query parameters coming soon)")
    }

    let path = stringSegment.content.text
    let name = fn.name.text

    var responseType: String
    guard let returnType = fn.signature.returnClause?.type else {
        throw MacroError.message("failed to extract response type")
    }
    // handle Optional? and [Array] types
    responseType = returnType.description.trimmingCharacters(in: .whitespaces)

    // Parse path parameters from the path string (e.g., "/users/:id/:commentId")
    let pathParamNames = Set(
        path.split(separator: "/")
            .filter { $0.starts(with: ":") }
            .map { String($0.dropFirst()) }  // Remove the ':' prefix
    )

    var bodyType: String?
    var pathParameters: [RouteParameter] = []
    var queryParameters: [RouteParameter] = []

    for param in fn.signature.parameterClause.parameters {
        // Handle body parameter for POST requests
        if param.firstName.text == "body" && httpMethod == .post {
            guard let paramType = param.type.as(IdentifierTypeSyntax.self)?.name.text else {
                throw MacroError.message("failed to extract body type from parameter")
            }
            bodyType = paramType
            continue
        }

        // Determine if optional and get base type
        let isOptional: Bool
        let baseType: String?

        if let optionalType = param.type.as(OptionalTypeSyntax.self),
            let wrappedType = optionalType.wrappedType.as(IdentifierTypeSyntax.self)?.name.text
        {
            isOptional = true
            baseType = wrappedType
        } else {
            isOptional = false
            baseType = param.type.as(IdentifierTypeSyntax.self)?.name.text
        }

        guard baseType == "String" else {
            throw MacroError.message("Unsupported parameter type: \(baseType ?? "unknown")")
        }

        let routeParam = RouteParameter(name: param.firstName.text, isOptional: isOptional)

        // Categorize as path or query parameter
        if pathParamNames.contains(param.firstName.text) {
            pathParameters.append(routeParam)
        } else {
            queryParameters.append(routeParam)
        }
    }

    return RouteMeta(
        name: name,
        path: path,
        method: httpMethod,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
        bodyType: bodyType,
        responseType: responseType
    )
}

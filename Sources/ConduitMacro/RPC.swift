import Core
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

func getRouteMetaIfIsRoute(node: MemberBlockItemSyntax, context: some MacroExpansionContext)
    -> RouteMeta?
{
    guard
        let funcDecl = node.decl.as(FunctionDeclSyntax.self),
        let routeAttribute =
            funcDecl.attributes.first,
        let routeAttributeName = routeAttribute.as(AttributeSyntax.self)?.attributeName.as(
            IdentifierTypeSyntax.self),
        HTTPMethod(rawValue: routeAttributeName.name.text) != nil,  // validate that this is a valid HTTP method
        let routeAttributeSyntax = routeAttribute.as(AttributeSyntax.self),
        let meta = try? routeHelper(node: routeAttributeSyntax, fn: funcDecl, context: context)
    else {
        return nil
    }
    return meta
}

func toStructPrefix(_ routeName: String) -> String {
    routeName.prefix(1).uppercased() + routeName.dropFirst()
}

public struct RPCMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf decl: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = decl.as(ProtocolDeclSyntax.self) else {
            throw MacroError.message("RPCClientMacro can only be applied to protocols")
        }
        let protocolName = protocolDecl.name.text
        let members = protocolDecl.memberBlock.members
        let routeDefs = members.compactMap({ getRouteMetaIfIsRoute(node: $0, context: context) })

        let pathBuilderStruct: DeclSyntax = {
            let routesWithPathParams: [RouteMeta] = routeDefs.filter {
                !$0.pathParameters.isEmpty
            }

            var pathParamStructs: [DeclSyntax] = []
            var pathConstructorMethods: [DeclSyntax] = []

            routesWithPathParams.forEach { (route: RouteMeta) in
                let pathParamNames = route.pathParameters.map { $0.name }
                let structPrefix = toStructPrefix(route.name)
                let pathParamStructName = structPrefix + "PathParams"
                let pathParamStruct: DeclSyntax = """
                    struct \(raw: pathParamStructName) {
                        \(raw: pathParamNames.map { "let \($0): String" }.joined(separator: "\n"))

                        init(\(raw: pathParamNames.map { "_ \($0): String" }.joined(separator: ", "))) {
                            \(raw: pathParamNames.map { "self.\($0) = \($0)" }.joined(separator: "\n"))
                        }
                    }
                    """
                pathParamStructs.append(pathParamStruct)
                let segments = route.path.split(separator: "/").filter { !$0.isEmpty }
                let pathExpression: String =
                    "/"
                    + segments.map { segment in
                        segment.prefix(1) == ":"
                            ? "\\(pathParams.\(segment.dropFirst()))" : String(segment)
                    }.joined(separator: "/")
                let pathMethod: DeclSyntax = """
                    static func \(raw: route.name)(pathParams: \(raw: pathParamStructName)) -> String {
                        return "\(raw: pathExpression)"
                    }
                    """
                pathConstructorMethods.append(pathMethod)
            }

            let structDecl: DeclSyntax = DeclSyntax(
                try! StructDeclSyntax("struct \(raw: protocolName)PathBuilder") {
                    for decl in pathParamStructs {
                        decl
                    }
                    for decl in pathConstructorMethods {
                        decl
                    }
                }
            )
            return structDecl
        }()

        // Generate nested parameter structs inside {ProtocolName}Params
        let paramsStruct: DeclSyntax? = {
            // Only generate if there are routes with parameters
            let routesWithParams = routeDefs.filter {
                !$0.pathParameters.isEmpty || !$0.queryParameters.isEmpty
            }
            guard !routesWithParams.isEmpty else { return nil }

            // Generate nested struct for each route
            let nestedStructs = routesWithParams.map { route in
                let allParams = route.pathParameters + route.queryParameters
                let properties = allParams.map { param in
                    let type = param.isOptional ? "String?" : "String"
                    return "let \(param.name): \(type)"
                }.joined(separator: "\n        ")

                // Capitalize first letter of method name for struct name
                let structName = toStructPrefix(route.name)

                return """
                        struct \(structName): Sendable, Codable {
                            \(properties)
                        }
                    """
            }.joined(separator: "\n\n    ")

            return """
                public struct \(raw: protocolName)Params {
                    \(raw: nestedStructs)
                }
                """ as DeclSyntax
        }()

        // Generate client struct methods
        let clientMethods: [DeclSyntax] = routeDefs.map { route -> DeclSyntax in
            let responseType: String = route.responseType ?? "Void"

            // Generate parameter list
            let allParams = route.pathParameters + route.queryParameters
            let parameters: FunctionParameterListSyntax = FunctionParameterListSyntax(
                (route.bodyType != nil
                    ? [
                        FunctionParameterSyntax(
                            firstName: .identifier("body"),
                            type: IdentifierTypeSyntax(name: .identifier(route.bodyType!)),
                            trailingComma: .commaToken())
                    ] : [])
                    + allParams.map {
                        param -> FunctionParameterSyntax in
                        let stringType = IdentifierTypeSyntax(name: .identifier("String"))
                        let optionalIfOptional =
                            param.isOptional
                            ? TypeSyntax(OptionalTypeSyntax(wrappedType: stringType))
                            : TypeSyntax(stringType)
                        return FunctionParameterSyntax(
                            firstName: .identifier(param.name),
                            type: optionalIfOptional,
                            trailingComma: .commaToken())
                    }
            )

            // Generate query items
            let queryItemsCode: CodeBlockSyntax = CodeBlockSyntax {
                route.queryParameters.map { param in
                    if param.isOptional {
                        return
                            "if let \(raw: param.name) = \(raw: param.name) { queryItems.append(URLQueryItem(name: \"\(raw: param.name)\", value: \(raw: param.name))) }"
                    } else {
                        return
                            "queryItems.append(URLQueryItem(name: \"\(raw: param.name)\", value: \(raw: param.name)))"
                    }
                }
            }

            // Generate path construction
            let structPrefix: String = toStructPrefix(route.name)
            let pathConstruction: DeclSyntax
            if !route.pathParameters.isEmpty {
                let pathParamNames = route.pathParameters.map { $0.name }.joined(separator: ", ")
                let pathParamStructName = structPrefix + "PathParams"
                pathConstruction =
                    "let path = \(raw: protocolName)PathBuilder.\(raw: route.name)(pathParams: \(raw: protocolName)PathBuilder.\(raw: pathParamStructName)(\(raw: pathParamNames)))"
            } else {
                pathConstruction = "let path = \"\(raw: route.path)\""
            }

            let getLogic: CodeBlockSyntax = CodeBlockSyntax {
                """
                let targetUrl = components.url!
                let session = URLSession(configuration: mergedConfig ?? .default)

                let (data, response) = try await session.data(from: targetUrl)
                let parsed = try JSONDecoder().decode(\(raw: responseType).self, from: data)


                guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                return parsed
                """
            }
            let postLogic: CodeBlockSyntax = CodeBlockSyntax {
                """
                let targetUrl = components.url!
                var request = URLRequest(url: targetUrl)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                request.httpBody = try JSONEncoder().encode(body)

                let session = URLSession(configuration: mergedConfig ?? .default)

                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse,
                        (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }

                let parsed = try JSONDecoder().decode(\(raw: responseType).self, from: data)
                return parsed
                """
            }
            let requestLogic = {
                switch route.method {
                case .get:
                    getLogic
                case .post:
                    postLogic
                }
            }()
            return """
                public func \(raw: route.name)(\( parameters)config: URLSessionConfiguration? = nil) async throws -> \(raw: responseType) {
                    \(pathConstruction)
                    var components = URLComponents(string: baseUrl + path)!
                    var queryItems: [URLQueryItem] = []
                    do \(queryItemsCode)
                    if !queryItems.isEmpty {
                        components.queryItems = queryItems
                    }

                    let mergedConfig: URLSessionConfiguration?

                    if let base = baseConfig {
                      if let override = config {
                        mergedConfig = base.merged(with: override)
                      } else {
                        mergedConfig = base
                      }
                    } else {
                      mergedConfig = config
                    }

                    do \(requestLogic)
                }
                """ as DeclSyntax
        }

        let clientStructDecl: DeclSyntax = DeclSyntax(
            try! StructDeclSyntax("public struct \(raw: protocolName)Client") {
                let baseUrlDecl: DeclSyntax = "let baseUrl: String"
                let baseConfigDecl: DeclSyntax = "let baseConfig: URLSessionConfiguration?"

                baseUrlDecl
                baseConfigDecl
                for decl in clientMethods {
                    decl
                }

                let liveDecl: DeclSyntax = """
                    public static func live(baseUrl: String, config: URLSessionConfiguration? = nil) -> \(raw: protocolName)Client {
                        return \(raw: protocolName)Client(baseUrl: baseUrl, baseConfig: config)
                    }
                    """
                liveDecl
            }
        )

        // Generate Routes enum with __conduit_registerRoutes method
        let routesEnum: DeclSyntax = {
            // Generate registration calls for each route
            let registrations = routeDefs.map { route in
                let responseType = route.responseType ?? "Void"
                let allParams = route.pathParameters + route.queryParameters
                let structName = route.name.prefix(1).uppercased() + route.name.dropFirst()

                // Determine parameter type
                let paramsType: String? =
                    !allParams.isEmpty ? "\(protocolName)Params.\(structName)" : nil

                // Generate parameter destructuring for the impl call
                let parameterList = allParams.map { param in
                    "\(param.name): params.\(param.name)"
                }.joined(separator: ", ")

                // Build impl call arguments
                let implCallArgs: String
                if route.bodyType != nil {
                    // Has body parameter
                    if allParams.isEmpty {
                        implCallArgs = "body: body"
                    } else {
                        implCallArgs = parameterList + ", body: body"
                    }
                } else {
                    // No body parameter
                    implCallArgs = allParams.isEmpty ? "" : parameterList
                }

                // Generate registration based on method and body type
                if route.method == .post, let bodyType = route.bodyType {
                    // POST with body
                    if let params = paramsType {
                        return """
                                builder.registerPOST(path: "\(route.path)") { (params: \(params), body: \(bodyType)) async throws -> \(responseType) in
                                    return try await impl.\(route.name)(\(implCallArgs))
                                }
                            """
                    } else {
                        return """
                                builder.registerPOST(path: "\(route.path)") { (body: \(bodyType)) async throws -> \(responseType) in
                                    return try await impl.\(route.name)(\(implCallArgs))
                                }
                            """
                    }

                } else {
                    // GET (or POST without body)
                    let methodName = route.method == .get ? "registerGET" : "registerPOST"
                    if let params = paramsType {
                        return """
                                builder.\(methodName)(path: "\(route.path)") { (params: \(params)) async throws -> \(responseType) in
                                    return try await impl.\(route.name)(\(parameterList))
                                }
                            """
                    } else {

                        return """
                                builder.\(methodName)(path: "\(route.path)") { () async throws -> \(responseType) in
                                    return try await impl.\(route.name)()
                                }
                            """
                    }
                }
            }.joined(separator: "\n\n        ")

            return """
                public enum \(raw: protocolName)Routes {
                    public static func __conduit_registerRoutes<Builder: RPCRouteBuilder>(
                        impl: any \(raw: protocolName),
                        builder: inout Builder
                    ) {
                        \(raw: registrations)
                    }
                }
                """ as DeclSyntax
        }()

        // Return all generated declarations
        var declarations: [DeclSyntax] = []
        if let paramsStruct = paramsStruct {
            declarations.append(paramsStruct)
        }
        declarations.append(pathBuilderStruct)
        declarations.append(clientStructDecl)
        declarations.append(routesEnum)

        return declarations
    }
}

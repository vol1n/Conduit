import Conduit
import Foundation
import Hummingbird
import NIOCore

// A box we promise is safe to send across threads
struct SendableBox<H>: @unchecked Sendable {
    let handler: H
}

/// Extract parameters from HTTP request and context into a Decodable struct
private func extractParams<Params: Decodable, Context: RequestContext>(
    from request: Request,
    context: Context
) throws -> Params {
    // Special case: no parameters
    if Params.self == Void.self {
        return (() as! Params)
    }

    // Build dictionary from all sources
    var allParams: [String: String] = [:]

    // Add path parameters (e.g., :id from /users/:id)
    for (name, value) in context.parameters {
        allParams[String(name)] = String(value)
    }

    // Add query parameters (?input=hello&limit=10)
    // Note: queryParameters is a collection of (Substring, Substring) tuples
    for (name, value) in request.uri.queryParameters {
        allParams[String(name)] = String(value)
    }

    // Convert to JSON and decode using JSONDecoder
    // This validates required vs optional fields automatically
    let jsonData = try JSONSerialization.data(withJSONObject: allParams)
    return try JSONDecoder().decode(Params.self, from: jsonData)
}

/// Hummingbird-specific implementation of RPCRouteBuilder
public struct HummingbirdRouteBuilder<Context: RequestContext>: RPCRouteBuilder {
    public var router: Router<Context>

    public init(router: Router<Context>) {
        self.router = router
    }

    public mutating func registerGET<Output: Sendable & Encodable>(
        path: StaticString,
        handler: @escaping @Sendable () async throws -> Output
    ) {
        let pathString = String(describing: path)
        let box = SendableBox(handler: handler)
        router.get(.init(pathString)) { request, context -> Response in
            // Call handler
            let output = try await box.handler()

            // Encode output
            if Output.self == Void.self {
                return Response(status: .ok)
            }

            let data = try JSONEncoder().encode(output)
            let buffer = ByteBuffer(bytes: data)
            let responseBody = ResponseBody(contentLength: data.count) { writer in
                try await writer.write(buffer)
                try await writer.finish(nil)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: responseBody
            )
        }
    }

    public mutating func registerGET<Params: Sendable & Decodable, Output: Sendable & Encodable>(
        path: StaticString,
        handler: @escaping @Sendable (Params) async throws -> Output
    ) {
        let pathString = String(describing: path)
        let box = SendableBox(handler: handler)
        router.get(.init(pathString)) { request, context -> Response in
            // Extract and validate parameters
            let params: Params
            do {
                params = try extractParams(from: request, context: context)
            } catch {
                throw HTTPError(
                    .badRequest, message: "Invalid parameters: \(error.localizedDescription)")
            }

            // Call handler
            let output = try await box.handler(params)

            // Encode output
            if Output.self == Void.self {
                return Response(status: .ok)
            }

            let data = try JSONEncoder().encode(output)
            let buffer = ByteBuffer(bytes: data)
            let responseBody = ResponseBody(contentLength: data.count) { writer in
                try await writer.write(buffer)
                try await writer.finish(nil)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: responseBody
            )
        }
    }

    public mutating func registerPOST<Body: Sendable & Decodable, Output: Sendable & Encodable>(
        path: StaticString,
        handler: @escaping @Sendable (Body) async throws -> Output
    ) {
        let pathString = String(describing: path)
        let box = SendableBox(handler: handler)
        router.post(.init(pathString)) { request, context -> Response in
            // Decode request body
            let body: Body
            do {
                body = try await request.decode(as: Body.self, context: context)
            } catch {
                throw HTTPError(
                    .badRequest, message: "Invalid request body: \(error.localizedDescription)")
            }

            // Call handler
            let output = try await box.handler(body)

            // Encode output
            if Output.self == Void.self {
                return Response(status: .ok)
            }

            let data = try JSONEncoder().encode(output)
            let buffer = ByteBuffer(bytes: data)
            let responseBody = ResponseBody(contentLength: data.count) { writer in
                try await writer.write(buffer)
                try await writer.finish(nil)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: responseBody
            )
        }
    }

    public mutating func registerPOST<
        Params: Sendable & Decodable, Body: Sendable & Decodable, Output: Sendable & Encodable
    >(
        path: StaticString,
        handler: @escaping @Sendable (Params, Body) async throws -> Output
    ) {
        let pathString = String(describing: path)
        let box = SendableBox(handler: handler)
        router.post(.init(pathString)) { request, context -> Response in
            // Extract and validate parameters
            let params: Params
            do {
                params = try extractParams(from: request, context: context)
            } catch {
                throw HTTPError(
                    .badRequest, message: "Invalid parameters: \(error.localizedDescription)")
            }

            // Decode request body
            let body: Body
            do {
                body = try await request.decode(as: Body.self, context: context)
            } catch {
                throw HTTPError(
                    .badRequest, message: "Invalid request body: \(error.localizedDescription)")
            }

            // Call handler
            let output = try await box.handler(params, body)

            // Encode output
            if Output.self == Void.self {
                return Response(status: .ok)
            }

            let data = try JSONEncoder().encode(output)
            let buffer = ByteBuffer(bytes: data)
            let responseBody = ResponseBody(contentLength: data.count) { writer in
                try await writer.write(buffer)
                try await writer.finish(nil)
            }
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: responseBody
            )
        }
    }
}

// MARK: - Convenience Extension

extension Router {
    /// Mount RPC routes using the builder pattern
    ///
    /// Example:
    /// ```swift
    /// var router = Router()
    /// let service = StringService()
    /// router = router.mountingRPC(service) { impl, builder in
    ///     StringAPIRoutes.__conduit_registerRoutes(impl: impl, builder: &builder)
    /// }
    /// ```
    public func mountingRPC<Impl>(
        _ impl: Impl,
        using registerRoutes: (Impl, inout HummingbirdRouteBuilder<Context>) -> Void
    ) -> Router<Context> {
        var builder = HummingbirdRouteBuilder<Context>(router: self)
        registerRoutes(impl, &builder)
        return builder.router
    }
}

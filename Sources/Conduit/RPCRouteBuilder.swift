// RPCRouteBuilder.swift
// Abstraction layer for registering routes without framework-specific types

import Foundation

/// A protocol for building RPC routes in a framework-agnostic way.
///
/// This protocol allows route registration without depending on specific
/// web framework types (like Hummingbird's Router). Framework-specific
/// implementations can conform to this protocol and translate to their
/// native routing APIs.
public protocol RPCRouteBuilder {
    /// Register a GET endpoint with a handler
    ///
    /// - Parameters:
    ///   - path: The URL path for the endpoint (e.g., "/users/:id")
    ///   - handler: An async throwing function that processes input and returns output

    mutating func registerGET<Output: Sendable & Encodable>(
        path: StaticString,
        handler: @escaping @Sendable () async throws -> Output
    )

    mutating func registerGET<Params: Sendable & Decodable, Output: Sendable & Encodable>(
        path: StaticString,
        handler: @escaping @Sendable (Params) async throws -> Output
    )

    mutating func registerPOST<
        Body: Sendable & Decodable, Output: Sendable & Encodable
    >(
        path: StaticString,
        handler: @escaping @Sendable (Body) async throws -> Output
    )

    mutating func registerPOST<
        Params: Sendable & Decodable, Body: Sendable & Decodable, Output: Sendable & Encodable
    >(
        path: StaticString,
        handler: @escaping @Sendable (Params, Body) async throws -> Output
    )
}

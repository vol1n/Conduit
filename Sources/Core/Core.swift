import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    //    case put = "PUT"
    //    case delete = "DELETE"
}

public struct RouteParameter {
    public let name: String
    public let isOptional: Bool

    public init(name: String, isOptional: Bool) {
        self.name = name
        self.isOptional = isOptional
    }
}

public struct RouteMeta {
    public let path: String
    public let method: HTTPMethod
    public let name: String
    public let pathParameters: [RouteParameter]
    public let queryParameters: [RouteParameter]

    public let bodyType: String?
    public let responseType: String?

    public init(
        name: String,
        path: String,
        method: HTTPMethod,
        pathParameters: [RouteParameter] = [],
        queryParameters: [RouteParameter] = [],
        bodyType: String?,
        responseType: String?
    ) {
        self.path = path
        self.method = method
        self.name = name
        self.pathParameters = pathParameters
        self.queryParameters = queryParameters
        self.bodyType = bodyType
        self.responseType = responseType
    }
}

extension URLSessionConfiguration {
    public func merged(
        with override: URLSessionConfiguration
    ) -> URLSessionConfiguration {
        // Start from base
        let result = self.copy() as! URLSessionConfiguration

        // Simple overwrites (config2 wins)
        result.allowsCellularAccess = override.allowsCellularAccess
        result.timeoutIntervalForRequest = override.timeoutIntervalForRequest
        result.timeoutIntervalForResource = override.timeoutIntervalForResource
        result.requestCachePolicy = override.requestCachePolicy
        result.networkServiceType = override.networkServiceType
        result.waitsForConnectivity = override.waitsForConnectivity
        result.httpMaximumConnectionsPerHost = override.httpMaximumConnectionsPerHost
        result.httpShouldUsePipelining = override.httpShouldUsePipelining
        result.httpShouldSetCookies = override.httpShouldSetCookies
        result.httpCookieAcceptPolicy = override.httpCookieAcceptPolicy
        result.networkServiceType = override.networkServiceType

        // Example: merge headers by key (override wins)
        if let baseHeaders = self.httpAdditionalHeaders as? [String: Any],
            let overrideHeaders = override.httpAdditionalHeaders as? [String: Any]
        {
            result.httpAdditionalHeaders = baseHeaders.merging(overrideHeaders) { _, new in new }
        } else if let overrideHeaders = override.httpAdditionalHeaders {
            result.httpAdditionalHeaders = overrideHeaders
        }

        // You can keep adding whatever properties you actually care about

        return result
    }
}

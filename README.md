# Conduit

**Type-safe RPC for Swift using macros**

Conduit is a Swift macro-based framework that generates both HTTP client and server code from a single protocol definition. Write your API once, get compile-time type safety everywhere.

## Features

✅ **Single Source of Truth** - Define your API as a Swift protocol  
✅ **Compile-Time Type Safety** - Parameters and return types checked at compile time  
✅ **Zero Boilerplate** - No manual routing or serialization code  
✅ **Framework Agnostic** - Server adapters for any web framework (Hummingbird included)  
✅ **Modern Swift** - Built with Swift 6.1, macros, and async/await  
✅ **iOS Ready** - Generated clients work seamlessly in iOS apps

## Quick Example

```swift
// 1. Define your API (in Shared package)
// Shared/Sources/API.swift
@RPC
public protocol StringAPI: Sendable {
    @GET("/reverse")
    func reverse(input: String) async throws -> ReverseResponse
}

// 2. Implement the server
// Server/sources/main.swift
struct StringService: StringAPI {
    func reverse(input: String) async throws -> ReverseResponse {
        return ReverseResponse(
            original: input,
            reversed: String(input.reversed())
        )
    }
}

// 3. Mount routes (Hummingbird example)
var router = Router()
var builder = HummingbirdRouteBuilder(router: router)
StringAPIRoutes.registerRoutes(impl: StringService(), builder: &builder)
router = builder.router

// 4. Use the client (iOS, macOS, anywhere)
// YourApp/ContentView.swift 
let client = StringAPIClient.live(baseUrl: "http://localhost:8080")
let response = try await client.reverse(input: "hello")
// response.reversed == "olleh"
```

## Installation

### Swift Package Manager

Add Conduit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/vol1n/Conduit.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourPackage",
        dependencies: [
            .product(name: "Conduit", package: "conduit")
        ]
    ),
]
```

## Usage

### 1. Define Your API

Create a shared package with your API protocol:

```swift
// Sources/Shared/API.swift
import Conduit

@RPC
public protocol TodoAPI: Sendable {
    @GET("/todos/:id")
    func getTodo(id: String) async throws -> Todo
    
    @GET("/todos")
    func listTodos(completed: Bool?, limit: Int?) async throws -> [Todo]
    
    @POST("/todos")
    func createTodo(body: CreateTodoRequest) async throws -> Todo
}
```

### 2. Implement the Server

```swift
// Server/Sources/main.swift
import Hummingbird
import ConduitServer
import Shared

struct TodoService: TodoAPI {
    func getTodo(id: String) async throws -> Todo {
        // Your implementation
    }
    
    func listTodos(completed: Bool?, limit: Int?) async throws -> [Todo] {
        // Your implementation
    }
    
    func createTodo(body: CreateTodoRequest) async throws -> Todo {
        // Your implementation
    }
}

let service = TodoService()
var router = Router()
var builder = HummingbirdRouteBuilder(router: router)
TodoAPIRoutes.registerRoutes(impl: service, builder: &builder)

let app = Application(router: builder.router)
try await app.runService()
```

### 3. Use the Client

The `@RPC` macro automatically generates a client:

```swift
// iOS/macOS client
let client = TodoAPIClient.live(baseUrl: "http://localhost:8080")

// All parameters are type-checked
let todo = try await client.getTodo(id: "123")
let todos = try await client.listTodos(completed: true, limit: 10)
let newTodo = try await client.createTodo(body: CreateTodoRequest(title: "Buy milk"))
```

## Running the Demo

```bash
# Start the server
cd ConduitDemo/Server
swift run

# Test with curl
curl 'http://localhost:8080/reverse?input=hello'

# Or run the iOS app
open ConduitDemo/ConduitDemoApp/ConduitDemoApp.xcodeproj
```

## Supported Features

### HTTP Methods
- ✅ `@GET` - Query parameters from function arguments
- ✅ `@POST` - Body from `body:` parameter, query params from other args

### Path Parameters
```swift
@GET("/users/:id/posts/:postId")
func getPost(id: String, postId: String) async throws -> Post
```

### Query Parameters
Optional parameters become optional query parameters:
```swift
@GET("/search")
func search(query: String, limit: Int?) async throws -> [Result]
// limit is optional in the query string
```

### Request Bodies
For POST requests:
```swift
@POST("/users")
func createUser(body: CreateUserRequest) async throws -> User
```

## Server Adapters

Conduit is framework-agnostic. Implement `RPCRouteBuilder` for any framework:

```swift
public protocol RPCRouteBuilder {
    mutating func registerGET<Params, Output>(
        path: StaticString,
        handler: @escaping @Sendable (Params) async throws -> Output
    )
    
    mutating func registerPOST<Params, Body, Output>(
        path: StaticString,
        handler: @escaping @Sendable (Params, Body) async throws -> Output
    )
}
```

Included adapters:
- ✅ **Hummingbird** - `ConduitServer` package

## Contributing

Contributions welcome! Please open an issue or PR.

## License

MIT License

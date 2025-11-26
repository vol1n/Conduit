# Conduit Todo App Demo

A minimal but production-ready Todo API built with Conduit, demonstrating type-safe RPC with Swift macros and SQLite persistence.

## What This Demonstrates

✅ **Path Parameters** - `/todos/:id` style routing  
✅ **Query Parameters** - Optional filtering with `?completed=true`  
✅ **POST with Body** - Creating and updating todos  
✅ **SQLite Persistence** - Real database storage (not just in-memory)  
✅ **Type Safety** - All parameters and responses are compile-time checked  
✅ **Zero Boilerplate** - One protocol definition generates client + server

## Structure

```
TodoApp/
├── Shared/          # API definition (shared between client & server)
├── Server/          # Hummingbird server with SQLite
└── Client/          # CLI client using generated code
```

## Quick Start

### 1. Start the Server

```bash
cd Server
swift run TodoServer
```

You should see:
```
🚀 Todo API server starting on http://127.0.0.1:8080
💾 Using SQLite database: /path/to/todos.db
📝 Endpoints:
   GET    /todos
   GET    /todos/:id
   POST   /todos
   POST   /todos/:id/complete
```

### 2. Run the Client

In a new terminal:

```bash
cd Client
swift run TodoClient
```

An interactive menu will appear:
```
🚀 Conduit Todo Client
Connected to: http://127.0.0.1:8080

Choose an action:
  1. List all todos
  2. List completed todos
  3. List incomplete todos
  4. Get todo by ID
  5. Create new todo
  6. Complete a todo
  7. Uncomplete a todo
  0. Exit
```

## API Examples

### Using curl

```bash
# List all todos
curl http://localhost:8080/todos

# Filter by completion status
curl http://localhost:8080/todos?completed=true

# Get specific todo
curl http://localhost:8080/todos/<id>

# Create a new todo
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Buy groceries"}'

# Complete a todo
curl -X POST http://localhost:8080/todos/<id>/complete \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'
```

### Using the Generated Client

```swift
let client = TodoAPIClient.live(baseUrl: "http://localhost:8080")

// List all todos
let todos = try await client.listTodos(completed: nil, config: nil)

// Get specific todo (path parameter)
let todo = try await client.getTodo(id: "123", config: nil)

// Create todo (POST body)
let newTodo = try await client.createTodo(
    body: CreateTodoRequest(title: "Learn Conduit"),
    config: nil
)

// Update todo (path parameter + POST body)
let updated = try await client.completeTodo(
    id: "123",
    body: UpdateTodoRequest(completed: true),
    config: nil
)
```

## The Magic: API Definition

This entire app is generated from one protocol:

```swift
@RPC
public protocol TodoAPI: Sendable {
    @GET("/todos")
    func listTodos(completed: String?) async throws -> [Todo]

    @GET("/todos/:id")
    func getTodo(id: String) async throws -> Todo

    @POST("/todos")
    func createTodo(body: CreateTodoRequest) async throws -> Todo

    @POST("/todos/:id/complete")
    func completeTodo(id: String, body: UpdateTodoRequest) async throws -> Todo
}
```

The `@RPC` macro automatically generates:
- ✨ `TodoAPIClient` - Type-safe HTTP client
- ✨ `TodoAPIParams.*` - Parameter validation structs
- ✨ `TodoAPIRoutes` - Server route registration
- ✨ `TodoAPIPathBuilder` - Path construction with parameters

## Database

The server uses SQLite3 (built into macOS/iOS) with a simple schema:

```sql
CREATE TABLE todos (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0
);
```

The database file (`todos.db`) persists between server restarts. Delete it to reset.

## What Makes This "Serious"

Unlike typical demos that use in-memory storage, this Todo app:

- **Persists data** with SQLite (survives restarts)
- **Uses proper IDs** (UUIDs, not incrementing integers)
- **Handles errors** (404 for missing todos, etc.)
- **Validates input** at compile-time (type-safe parameters)
- **Shows real patterns** you'd use in production

## Extending the Demo

Try adding:

- `DELETE /todos/:id` - Delete a todo
- `PUT /todos/:id` - Update title and completion
- Pagination - `?limit=10&offset=20`
- Search - `?search=keyword`
- Due dates - Add `dueDate` field
- iOS app - SwiftUI client using `TodoAPIClient`

## Troubleshooting

**Port already in use:**
```bash
lsof -ti:8080 | xargs kill
```

**Database locked:**
```bash
rm todos.db
# Server will recreate on next start
```

**Can't connect from client:**
Make sure the server is running first!

---

**Built with Conduit** - Type-safe RPC for Swift 🚀
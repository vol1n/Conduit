import ConduitServer
import Foundation
import Hummingbird
import TodoShared

// MARK: - Service Implementation

struct TodoService: TodoAPI {
    let store: TodoStore

    func listTodos(completed: String?) async throws -> [Todo] {
        let completedBool = completed.flatMap { $0 == "true" ? true : $0 == "false" ? false : nil }
        return await store.getAll(completed: completedBool)
    }

    func getTodo(id: String) async throws -> Todo {
        guard let todo = await store.get(id: id) else {
            throw HTTPError(.notFound, message: "Todo not found")
        }
        return todo
    }

    func createTodo(body: CreateTodoRequest) async throws -> Todo {
        guard let todo = await store.create(title: body.title) else {
            throw HTTPError(.internalServerError, message: "Failed to create todo")
        }
        return todo
    }

    func completeTodo(id: String, body: UpdateTodoRequest) async throws -> Todo {
        guard let todo = await store.update(id: id, completed: body.completed) else {
            throw HTTPError(.notFound, message: "Todo not found")
        }
        return todo
    }
}

// MARK: - Server Setup

// Create store and service
let store = try TodoStore(dbPath: "todos.db")

// Seed with initial data if empty
await store.seed()

let service = TodoService(store: store)

// Setup router with Conduit routes
var router = Router()
var builder = HummingbirdRouteBuilder(router: router)

TodoAPIRoutes.__conduit_registerRoutes(impl: service, builder: &builder)
router = builder.router

// Create and run the application
let app = Application(
    router: router,
    configuration: .init(address: .hostname("127.0.0.1", port: 8080))
)

print("🚀 Todo API server starting on http://127.0.0.1:8080")
print("💾 Using SQLite database: \(FileManager.default.currentDirectoryPath)/todos.db")
print("📝 Endpoints:")
print("   GET    /todos")
print("   GET    /todos/:id")
print("   POST   /todos")
print("   POST   /todos/:id/complete")

try await app.runService()

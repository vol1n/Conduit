import Conduit
import Foundation

// MARK: - Models

public struct Todo: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let completed: Bool

    public init(id: String, title: String, completed: Bool) {
        self.id = id
        self.title = title
        self.completed = completed
    }
}

public struct CreateTodoRequest: Codable, Sendable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct UpdateTodoRequest: Codable, Sendable {
    public let completed: Bool

    public init(completed: Bool) {
        self.completed = completed
    }
}

// MARK: - API

@RPC
public protocol TodoAPI: Sendable {
    /// List all todos, optionally filtered by completion status
    @GET("/todos")
    func listTodos(completed: String?) async throws -> [Todo]

    /// Get a single todo by ID
    @GET("/todos/:id")
    func getTodo(id: String) async throws -> Todo

    /// Create a new todo
    @POST("/todos")
    func createTodo(body: CreateTodoRequest) async throws -> Todo

    /// Update a todo's completion status
    @POST("/todos/:id/complete")
    func completeTodo(id: String, body: UpdateTodoRequest) async throws -> Todo
}

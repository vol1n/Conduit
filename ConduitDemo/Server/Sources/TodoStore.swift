import Foundation
import SQLite3
import TodoShared

actor TodoStore {
    private nonisolated(unsafe) var db: OpaquePointer?
    private let dbPath: String

    init(dbPath: String = "todos.db") throws {
        self.dbPath = dbPath

        // Open database
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            throw NSError(
                domain: "SQLite", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open database"])
        }

        // Create table if it doesn't exist
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS todos (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0
            );
            """

        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw NSError(
                domain: "SQLite", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create table: \(errmsg)"])
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func getAll(completed: Bool?) -> [Todo] {
        var todos: [Todo] = []

        let query: String
        if let completed = completed {
            query = "SELECT id, title, completed FROM todos WHERE completed = \(completed ? 1 : 0)"
        } else {
            query = "SELECT id, title, completed FROM todos"
        }

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let completed = sqlite3_column_int(statement, 2) != 0

                todos.append(Todo(id: id, title: title, completed: completed))
            }
        }

        sqlite3_finalize(statement)
        return todos
    }

    func get(id: String) -> Todo? {
        let query = "SELECT id, title, completed FROM todos WHERE id = ?"
        var statement: OpaquePointer?
        var todo: Todo?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let completed = sqlite3_column_int(statement, 2) != 0

                todo = Todo(id: id, title: title, completed: completed)
            }
        }

        sqlite3_finalize(statement)
        return todo
    }

    func create(title: String) -> Todo? {
        let id = UUID().uuidString
        let query = "INSERT INTO todos (id, title, completed) VALUES (?, ?, 0)"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (title as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return Todo(id: id, title: title, completed: false)
            }
        }

        sqlite3_finalize(statement)
        return nil
    }

    func update(id: String, completed: Bool) -> Todo? {
        let query = "UPDATE todos SET completed = ? WHERE id = ?"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, completed ? 1 : 0)
            sqlite3_bind_text(statement, 2, (id as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) == SQLITE_DONE {
                sqlite3_finalize(statement)
                return get(id: id)
            }
        }

        sqlite3_finalize(statement)
        return nil
    }

    func seed() {
        // Check if we already have todos
        let count = getAll(completed: nil).count
        if count > 0 { return }

        // Seed initial data
        _ = create(title: "Learn Conduit")
        _ = create(title: "Build an API with SQLite")
        _ = create(title: "Ship to production")
    }
}

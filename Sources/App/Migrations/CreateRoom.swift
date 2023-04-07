import Fluent

struct CreateRoom: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("rooms")
            .id()
            .field("admin_id", .uuid, .required, .references("users", .id))
            .field("name", .string, .required)
            .field("is_open", .bool, .required)
            .field("invite_code", .string)
            .field("status", .string)
            .unique(on: "name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("rooms").delete()
    }
}

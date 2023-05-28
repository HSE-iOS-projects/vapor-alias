import Fluent

struct CreateTeam: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("teams")
            .id()
            .field("id_room", .uuid, .required, .references("rooms", .id))
            .field("name", .string, .required)
            .field("round", .int64, .required)
            .field("total_points", .int, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("teams").delete()
    }
}

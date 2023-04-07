import Fluent

struct CreateParticipants: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("participants")
            .id()
            .field("room_id", .uuid, .required, .references("rooms", .id))
            .field("user_id", .uuid, .required, .references("users", .id))
            .field("team_id", .uuid, .references("teams", .id))
            .unique(on: "user_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("participants").delete()
    }
}

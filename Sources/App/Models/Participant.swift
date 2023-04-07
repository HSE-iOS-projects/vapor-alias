import Vapor
import Fluent

final class Participant: Content, Model {

    static let schema = "participants"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "room_id")
    var roomID: UUID

    @Field(key: "user_id")
    var userID: UUID

    @Field(key: "team_id")
    var teamID: UUID?

    init() { }

    init(id: UUID? = nil, roomID: UUID, userID: UUID, teamID: UUID? = nil) {
        self.id = id
        self.roomID = roomID
        self.userID = userID
        self.teamID = teamID
    }

}


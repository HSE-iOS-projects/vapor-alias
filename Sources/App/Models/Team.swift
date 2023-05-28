import Vapor
import Fluent

final class Team: Content, Model {
    static let schema = "teams"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "id_room")
    var roomID: UUID

    @Field(key: "name")
    var name: String
    
    @Field(key: "round")
    var round: Int

    @Field(key: "total_points")
    var totalPoints: Int

    init() { }

    init(id: UUID? = nil, roomID: UUID, name: String, totalPoints: Int = 0, round: Int = 0) {
        self.id = id
        self.roomID = roomID
        self.name = name
        self.totalPoints = totalPoints
        self.round = round
    }
}

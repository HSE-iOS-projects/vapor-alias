import Vapor

struct GetRoomInfoResponse: Content {
    let name: String
    let id: UUID
    let participants: [UserInGame]
    let isAdmin: Bool
    let key: String?
}

struct UserInGame: Codable {
    let id: UUID
    let name: String
    let teamId: UUID?
    let team: String?
}

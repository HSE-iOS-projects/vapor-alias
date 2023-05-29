import Vapor

struct GetRoomInfoResponse: Content {
    let name: String
    let id: UUID
    let participants: [Participant]
    let isAdmin: Bool
    let key: String?
}

import Vapor

struct CreateRoomResponse: Content {
    let roomID: UUID
    let inviteCode: String?
}

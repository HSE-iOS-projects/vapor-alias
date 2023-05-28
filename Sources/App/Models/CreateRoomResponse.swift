import Vapor

struct CreateRoomResponse: Content {
    let roomID: UUID
    let roomName: String
    let inviteCode: String?
}

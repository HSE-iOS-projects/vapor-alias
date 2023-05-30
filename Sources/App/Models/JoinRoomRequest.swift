import Vapor

struct JoinRoomRequest: Content {
    let roomID: UUID?
    let inviteCode: String?
}

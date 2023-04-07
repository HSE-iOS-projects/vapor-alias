import Vapor

struct DeleteUserFromRoomRequest: Content {
    let participantID: UUID
    let roomID: UUID
}

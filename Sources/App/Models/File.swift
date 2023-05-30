import Vapor

struct DeleteRoomRequest: Content {
    let id: UUID
}

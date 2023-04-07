import Vapor

struct ChangeRoomStateRequest: Content {
    let roomID: UUID
    let isOpen: Bool
}

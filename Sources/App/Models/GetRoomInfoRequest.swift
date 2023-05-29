import Vapor

struct GetRoomInfoRequest: Content {
    let id: UUID
}

import Vapor

struct CreateRoomRequest: Content {
    let name: String
    let is_open: Bool
}

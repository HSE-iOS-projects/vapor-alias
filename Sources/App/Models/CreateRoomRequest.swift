import Vapor

struct CreateRoomRequest: Content {
    let name: String
    let url: String
    let is_open: Bool
}

import Vapor

struct GetRoomsResponse: Content {
    let roomID: UUID
    let isActivRoom: Bool
    let url: String
    let isAdmin: Bool
    let name: String
    let isOpen: Bool
    let status: String
}

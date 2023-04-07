import Vapor

struct GetRoomsResponse: Content {
    let roomID: UUID
    let name: String
    let isOpen: Bool
    let status: String
}

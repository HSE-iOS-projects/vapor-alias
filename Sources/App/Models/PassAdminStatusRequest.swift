import Vapor

struct PassAdminStatusRequest: Content {
    let userID: UUID
    let roomID: UUID
}

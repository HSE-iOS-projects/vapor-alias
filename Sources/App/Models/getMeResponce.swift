import Vapor

struct GetMeResponse: Content {
    let nickname: String
    let roomID: UUID?
    let roomName: String?
}

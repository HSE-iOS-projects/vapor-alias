import Vapor

struct getMeResponse: Content {
    let nickname: String
    let roomID: UUID?
    let roomName: String?
}

import Vapor

struct NextRoundRequest: Content {
    let points: Int
    let roomID: UUID
}

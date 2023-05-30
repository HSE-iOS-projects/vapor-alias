import Vapor

struct StartGameRequest: Content {
    let numberOfRounds: Int
}

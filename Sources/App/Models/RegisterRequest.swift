import Vapor

struct RegisterRequest: Content {
    let nickname: String
    let password: String
}

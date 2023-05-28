import Vapor

struct LoginRequest: Content {
    let nickname: String
    let password: String
}

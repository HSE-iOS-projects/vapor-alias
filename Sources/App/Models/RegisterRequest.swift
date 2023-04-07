import Vapor

struct RegisterRequest: Content {
    let email: String
    let password: String
}

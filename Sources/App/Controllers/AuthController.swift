import Fluent
import Vapor

struct AuthController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let authRoutes = routes.grouped("auth")
        authRoutes.post("register", use: register)
        authRoutes.post("login", use: login)
    }

    func register(req: Request) async throws -> Token {
        let registerRequest = try req.content.decode(RegisterRequest.self)
        let passwordHash = try Bcrypt.hash(registerRequest.password)
        let user = User(nickname: registerRequest.nickname, password: passwordHash)
        try await user.save(on: req.db).get()
        
        let expirationTime = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let payload = AuthPayload(subject: try user.requireID().uuidString, expirationTime: expirationTime)
        let token = try req.jwt.sign(payload)
        return Token(token: token.description)
    }

    func login(req: Request) async throws -> Token {
        let loginRequest = try req.content.decode(LoginRequest.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$nickname == loginRequest.nickname)
            .first()
        else {
            throw Abort(.notFound)
        }
 
        let passwordIsValid = try Bcrypt.verify(loginRequest.password, created: user.password)

        guard passwordIsValid else {
            throw Abort(.unauthorized)
        }

        let expirationTime = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let payload = AuthPayload(subject: try user.requireID().uuidString, expirationTime: expirationTime)
        let token = try req.jwt.sign(payload)
        return Token(token: token.description)
    }

}

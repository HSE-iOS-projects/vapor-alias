import Fluent
import Vapor

struct GameController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let authRoutes = routes.grouped("game")
        authRoutes.post("create", use: create)
        authRoutes.post("join", use: join)
    }

    func create(req: Request) async throws -> CreateRoomResponse {
        let roomReq = try req.content.decode(CreateRoomRequest.self)
        let user = try await TokenHelpers.getUserID(req: req)

        let inviteCode = roomReq.is_open ? nil : String.randomString(length: 20)

        let room = Room(adminId: user,
                        name: roomReq.name,
                        isOpen: roomReq.is_open,
                        inviteCode: inviteCode,
                        status: "Created")

        try await room.save(on: req.db).get()
        let response = CreateRoomResponse(roomID: try room.requireID(), inviteCode: room.inviteCode)
        return response
    }

    func join(req: Request) async throws -> Token {
        let loginRequest = try req.content.decode(LoginRequest.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
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


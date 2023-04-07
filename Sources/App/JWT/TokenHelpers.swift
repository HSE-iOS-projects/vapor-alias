import JWT
import Vapor

class TokenHelpers {

    class func getUserID(req: Request) async throws -> UUID {
        guard let token = req.headers.first(name: "Auth") else {
            throw Abort(.badRequest)
        }

        let jwtSigner: JWTSigner = .hs256(key: "mySecretKey")
        let payload = try jwtSigner.verify(token, as: AuthPayload.self)

        guard let userID = UUID(uuidString: payload.subject.value) else {
            throw Abort(.notFound)
        }

        return userID
    }

}

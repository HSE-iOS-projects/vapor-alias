import Fluent
import Vapor
import JWT

struct WebSocketController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let wordsRoutes = routes.grouped("words")
        wordsRoutes.webSocket("game", onUpgrade: webSocketBehavior())

        func webSocketBehavior() -> (Request, WebSocket) -> () {
            let closure: (Request, WebSocket) -> () = { req, ws in

                guard let userId = getUserFromWSConnection(req: req, ws: ws) else {
                    ws.close()
                    return
                }

                ConnectionsManager.shared.addConnection(userId: userId, connection: ws)
            }

            return closure
        }

    }

    private func getUserFromWSConnection(req: Request, ws: WebSocket) -> UUID? {
        guard let userToken = req.headers.first(name: "Auth") else {
            ws.send("Incorrect request without Auth header")
            ws.close()
            return nil
        }

        let jwtSigner: JWTSigner = .hs256(key: "mySecretKey")
        do {
            let payload = try jwtSigner.verify(userToken, as: AuthPayload.self)

            guard let userID = UUID(uuidString: payload.subject.value) else {
                ws.send("Bad token")
                ws.close()
                return nil
            }

            return userID
        }
        catch {
            ws.send("Error")
            ws.close()
        }

        return nil
    }

}

import Fluent
import Vapor

func routes(_ app: Application) throws {
    try app.register(collection: AuthController())
    try app.register(collection: GameController())
    try app.register(collection: WordsController())
    try app.register(collection: WebSocketController())
}

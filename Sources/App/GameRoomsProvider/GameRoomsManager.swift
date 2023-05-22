import Foundation
import Vapor

final class GameRoomsManager {

    static let shared = GameRoomsManager()

    var rooms = [GameRoom]()

    private init() { }

    func createRoom(userId: UUID, roomId: UUID) throws {
        guard let connection = ConnectionsManager.shared.getConnection(userId: userId) else {
            throw Abort(.notFound)
        }

        rooms.append(GameRoom(admin: userId, connection: connection, roomId: roomId))
    }

    func addUserToRoom(userId: UUID, roomId: UUID) throws {
        guard let room = rooms.first(where: { $0.roomId == roomId}) else {
            throw Abort(.notFound)
        }

        guard let connection = ConnectionsManager.shared.getConnection(userId: userId) else {
            throw Abort(.badRequest)
        }

        room.addConnection(connection: connection, userId: userId)
    }

    func deleteUserFromRoom(userId: UUID, roomId: UUID) throws {
        guard let room = rooms.first(where: { $0.roomId == roomId}) else {
            throw Abort(.notFound)
        }

        room.removeConnection(userId: userId)
    }

}

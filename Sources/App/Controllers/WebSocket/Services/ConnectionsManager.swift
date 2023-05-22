import WebSocketKit
import Foundation

final class ConnectionsManager {

    static let shared = ConnectionsManager()

    private var connections = [UUID: WebSocket]()

    func addConnection(userId: UUID, connection: WebSocket) {
        connections[userId] = connection
    }

    func removeConnection(userId: UUID) {
        connections.removeValue(forKey: userId)
    }

    func getConnection(userId: UUID) -> WebSocket? {
        connections[userId]
    }

}

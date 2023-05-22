import WebSocketKit
import Foundation

final class GameRoom {

    let roomId: UUID

    private var connections: [UUID: WebSocket]

    init(admin: UUID, connection: WebSocket, roomId: UUID) {
        connections = [admin: connection]
        self.roomId = roomId
    }

    func send(message: String) {
        for (_, ws) in connections {
            ws.send(message)
        }
    }

    func addConnection(connection: WebSocket, userId: UUID) {
        connections[userId] = connection
    }

    func removeConnection(userId: UUID) {
        connections.removeValue(forKey: userId)
    }
    
}

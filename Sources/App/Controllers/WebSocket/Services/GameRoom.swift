import WebSocketKit
import Vapor
import Foundation

final class GameRoom {
    
    enum Receivers {
        case all
        case active(players: [UUID])
    }

    let roomId: UUID

    private var connections: [UUID: WebSocket]

    init(admin: UUID, connection: WebSocket, roomId: UUID) {
        connections = [admin: connection]
        self.roomId = roomId
    }
    
    func sendWords(activeUser: UUID, waiting: [UUID]) throws {
        let words = WordsProvider.getRandomWords(num: 20)
        let data = try? JSONEncoder().encode(words)
        guard let baseArray = data?.base64EncodedString() else {
            throw Abort(.internalServerError)
        }
        
        send(message: baseArray, receivers: .active(players: [activeUser]))
        send(message: "wait", receivers: .active(players: waiting))
    }

    func send(message: String, receivers: Receivers) {
        switch receivers {
        case .all:
            for (_, ws) in connections {
                ws.send(message)
            }
            
        case .active(let players):
            for player in players {
                connections[player]?.send(message)
            }
        }
    }

    func addConnection(connection: WebSocket, userId: UUID) {
        connections[userId] = connection
    }

    func removeConnection(userId: UUID) {
        connections.removeValue(forKey: userId)
    }
    
}

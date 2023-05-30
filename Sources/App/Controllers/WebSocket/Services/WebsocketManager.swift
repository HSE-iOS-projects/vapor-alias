import WebSocketKit
import Vapor
import Foundation

final class WebsocketManager {
    
    static let shared = WebsocketManager()
    
    private var connections = [UUID: WebSocket]()
    
    private init() {}
    
    func sendWords(activeUser: UUID, waiting: [UUID]) throws {
        let words = WordsProvider.getRandomWords(num: 20)
        let data = try? JSONEncoder().encode(words)
        guard let baseArray = data?.base64EncodedString() else {
            throw Abort(.internalServerError)
        }
        
        send(message: baseArray, receivers: [activeUser])
        send(message: "wait", receivers: waiting)
    }
        
    func send(message: String, receivers: [UUID]) {
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

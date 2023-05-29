import Fluent
import Vapor

struct GameController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let gameRoutes = routes.grouped("game")
        gameRoutes.get("getMe", use: getMe)
        gameRoutes.post("create", use: create)
        gameRoutes.get("getAllRooms", use: getAllRooms)
        gameRoutes.get("getMyRoom", use: getMyRoom)
        gameRoutes.post("changeRoomState", use: changeRoomState)
        gameRoutes.post("joinRoom", use: joinRoomRequest)
        gameRoutes.delete("deleteUserFromRoomRequest", use: deleteUserFromRoomRequest)
        gameRoutes.delete("leaveRoomRequest", use: leaveRoomRequest)
        gameRoutes.put("passAdminStatus", use: passAdminStatus)
        gameRoutes.post("createTeamRequest", use: createTeamRequest)
        gameRoutes.group(":roomID") { room in
            room.delete(use: deleteRoomRequest)
            room.get(use: getRoomParticipants)
        }
        gameRoutes.group(":teamID") { team in
            team.put(use: joinTeamRequest)
        }
        gameRoutes.put("addToTeam", use: addToTeamRequest)
    }
    
    func getMe(req: Request) async throws -> getMeResponse {
        let user = try await TokenHelpers.getUserID(req: req)
        guard let nickname = try await User.query(on: req.db)
                                        .filter(\.$id == user)
                                        .first()?.nickname else {
            throw Abort(.notFound)
        }
        
        var participant: Participant?
        var roomName: String?
        
        if let part = try? await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first() {
            participant = part
            
            let room = try? await Room.query(on: req.db)
                .filter(\.$id == part.roomID)
                .first()?.name
            
            roomName = room
        }

        return getMeResponse(nickname: nickname, roomID: participant?.roomID, roomName: roomName)
    }
    
    func create(req: Request) async throws -> CreateRoomResponse {
        let roomReq = try req.content.decode(CreateRoomRequest.self)
        let user = try await TokenHelpers.getUserID(req: req)

        let inviteCode = roomReq.is_open ? nil : String.randomString(length: 20)

        let room = Room(adminId: user,
                        name: roomReq.name,
                        url: roomReq.url,
                        isOpen: roomReq.is_open,
                        inviteCode: inviteCode,
                        status: "Waiting")

        try await room.save(on: req.db).get()
        let roomId = try room.requireID()
    
        try GameRoomsManager.shared.createRoom(userId: user, roomId: roomId)

        let response = CreateRoomResponse(roomID: roomId, roomName: roomReq.name, inviteCode: room.inviteCode)
        return response
    }

    func getAllRooms(req: Request) async throws -> [GetRoomsResponse] {
        let userId = try await TokenHelpers.getUserID(req: req)
    
        let activeRoomId = try await Participant.query(on: req.db)
            .filter(\.$userID == userId)
            .first()?.id ?? UUID()
        

        let rooms = try await Room.query(on: req.db).all().map {
            GetRoomsResponse(roomID: try $0.requireID(),
                             isActivRoom: $0.id == activeRoomId,
                             url: $0.url,
                             isAdmin: $0.adminId == userId,
                             name: $0.name,
                             isOpen: $0.isOpen,
                             status: $0.status)
        }

        return rooms
    }

    func getMyRoom(req: Request) async throws -> [GetRoomsResponse] {
        let user = try await TokenHelpers.getUserID(req: req)

        let rooms = try await Room.query(on: req.db)
            .filter(\.$adminId == user)
            .all()
            .map { GetRoomsResponse(roomID: try $0.requireID(),
                                    isActivRoom: true,
                                    url: $0.url,
                                    isAdmin: $0.adminId == user,
                                    name: $0.name,
                                    isOpen: $0.isOpen,
                                    status: $0.status)
            }

        return rooms
    }

    func changeRoomState(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let roomModel = try req.content.decode(ChangeRoomStateRequest.self)

        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomModel.roomID)
            .filter(\.$adminId == user)
            .first()
        else {
            return .notFound
        }

        room.isOpen = roomModel.isOpen
        room.inviteCode = roomModel.isOpen ? nil : String.randomString(length: 20)
        try await room.update(on: req.db)
        return .ok
    }

    func deleteRoomRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)

        guard let room = try await Room.find(req.parameters.get("roomID"), on: req.db),
              room.adminId == user
        else {
            throw Abort(.notFound)
        }

        try await room.delete(on: req.db)
        return .ok
    }

    func joinRoomRequest(req: Request) async throws -> HTTPStatus {
        let joinReq = try req.content.decode(JoinRoomRequest.self)
        let user = try await TokenHelpers.getUserID(req: req)

        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == joinReq.roomID)
            .first()
        else {
            return .notFound
        }

        if !room.isOpen && room.inviteCode != joinReq.inviteCode {
            return .badRequest
        }

        let roomId = try room.requireID()
        let participant = Participant(roomID: roomId, userID: user)

        try await participant.save(on: req.db)

        try GameRoomsManager.shared.addUserToRoom(userId: user, roomId: roomId)
        return .ok
    }

    func getRoomParticipants(req: Request) async throws -> [Participant] {
        let _ = try await TokenHelpers.getUserID(req: req)

        guard let reqID = req.parameters.get("roomID"),
              let id = UUID(reqID)
        else {
            throw Abort(.notFound)
        }

        let users = try await Participant.query(on: req.db)
            .filter(\.$roomID == id)
            .all()

        return users
    }

    func deleteUserFromRoomRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let deleteReq = try req.content.decode(DeleteUserFromRoomRequest.self)

        guard let room = try await Room.find(deleteReq.roomID, on: req.db),
              room.adminId == user
        else {
            return .badRequest
        }

        guard let participant = try await Participant.find(deleteReq.participantID, on: req.db) else {
            return .badRequest
        }

        try await participant.delete(on: req.db)

        try GameRoomsManager.shared.deleteUserFromRoom(userId: deleteReq.participantID, roomId: deleteReq.roomID)

        return .ok
    }

    func leaveRoomRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)

        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first()
        else {
            return .badRequest
        }

        try await participant.delete(on: req.db)
        return .ok
    }

    func passAdminStatus(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let passReq = try req.content.decode(PassAdminStatusRequest.self)

        guard let room = try await Room.find(passReq.roomID, on: req.db),
              room.adminId == user
        else {
            return .badRequest
        }

        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == passReq.userID)
            .filter(\.$roomID == room.requireID())
            .first()
        else {
            return .badRequest
        }

        room.adminId = participant.userID
        try await room.update(on: req.db)
        return .ok
    }

    func createTeamRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let teamReq = try req.content.decode(Team.self)

        guard let room = try await Room.find(teamReq.roomID, on: req.db),
              room.adminId == user
        else {
            return .badRequest
        }

        try await teamReq.save(on: req.db)
        return .ok
    }

    func joinTeamRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)

        guard let teamID = req.parameters.get("teamID"),
              let id = UUID(teamID)
        else {
            throw Abort(.notFound)
        }

        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first()
        else {
            return .badRequest
        }

        participant.teamID = id
        try await participant.update(on: req.db)
        return .ok
    }
    
    func addToTeamRequest(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let addToTeamReq = try req.content.decode(AddUserToTeamRequest.self)

        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == addToTeamReq.userID)
            .first()
        else {
            return .notFound
        }

        participant.teamID = addToTeamReq.teamID
        try await participant.update(on: req.db)
        return .ok
    }
    
    func nextRound(req: Request) async throws -> HTTPStatus {
        
        
        return .ok
    }

}

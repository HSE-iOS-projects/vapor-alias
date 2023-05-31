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
        gameRoutes.post("getRoomInfo", use: getRoomInfo)
        gameRoutes.delete("deleteTeam", use: deleteTeam)
        gameRoutes.post("startGame", use: startGame)
        gameRoutes.post("nextRound", use: nextRound)
    }
    
    func getMe(req: Request) async throws -> GetMeResponse {
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
        
        return GetMeResponse(nickname: nickname, roomID: participant?.roomID, roomName: roomName)
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
        
        let response = CreateRoomResponse(roomID: roomId, roomName: roomReq.name, inviteCode: room.inviteCode)
        return response
    }
    
    func getAllRooms(req: Request) async throws -> [GetRoomsResponse] {
        let userId = try await TokenHelpers.getUserID(req: req)
        
        let activeRoomId = try await Participant.query(on: req.db)
            .filter(\.$userID == userId)
            .first()?.id ?? UUID()
        
        
        let rooms = try await Room.query(on: req.db)
            .filter(\.$isOpen == true)
            .all().map {
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
    
    func getRoomInfo(req: Request) async throws -> GetRoomInfoResponse {
        let user = try await TokenHelpers.getUserID(req: req)
        
        let roomReq = try req.content.decode(GetRoomInfoRequest.self)
        let roomId = roomReq.id
        
        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomId)
            .first() else {
            throw Abort(.notFound)
        }
        
        let participants = try await Participant.query(on: req.db)
            .filter(\.$roomID == roomId)
            .all()
        
        var users = [User]()
        
        for participant in participants {
            if let roomUser = try await User.query(on: req.db)
                .filter(\.$id == participant.userID)
                .first() {
                users.append(roomUser)
            }
        }
        
        var teams = [Team]()
        
        for participant in participants {
            if let teamId = participant.teamID,
               let team = try await Team.query(on: req.db)
                .filter(\.$id == teamId)
                .first() {
                teams.append(team)
            }
        }
        
        var usersInGame = [UserInGame]()
        
        for participant in participants {
            let id = try participant.requireID()
            let name = users.first(where: { $0.id == participant.userID })?.nickname ?? ""
            let teamId = participant.teamID
            var team: String?
            if let teamId = teamId {
                team = try teams.first(where: { try $0.requireID() == teamId})?.name
            }
            usersInGame.append(.init(id: id, name: name, teamId: teamId, team: team))
        }
    
        let roomTeams = try await Team.query(on: req.db)
                   .filter(\.$roomID == roomId)
                   .all()
        
        return GetRoomInfoResponse(name: room.name,
                                   id: roomId,
                                   participants: usersInGame,
                                   teams: roomTeams,
                                   url: room.url,
                                   isAdmin: room.adminId == user,
                                   key: room.inviteCode)
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
    
    func joinRoomRequest(req: Request) async throws -> GetRoomInfoResponse {
        let joinReq = try req.content.decode(JoinRoomRequest.self)
        let user = try await TokenHelpers.getUserID(req: req)
        
        var room: Room?
        if let id = joinReq.roomID {
            room = try await Room.query(on: req.db)
                .filter(\.$id == id)
                .filter(\.$isOpen == true)
                .first()
        
        } else if let code = joinReq.inviteCode {
            room = try await Room.query(on: req.db)
                .filter(\.$inviteCode == code)
                .filter(\.$isOpen == false)
                .first()
        }
        
        guard let room = room else {
            throw Abort(.notFound)
        }
        
        if !room.isOpen && room.inviteCode != joinReq.inviteCode {
            throw Abort(.badRequest)
        }
        
        let roomId = try room.requireID()
        let participant = Participant(roomID: roomId, userID: user)
        
        try await participant.save(on: req.db)
        
//        try GameRoomsManager.shared.addUserToRoom(userId: user, roomId: roomId)
    
        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomId)
            .first() else {
            throw Abort(.notFound)
        }
        
        let participants = try await Participant.query(on: req.db)
            .filter(\.$roomID == roomId)
            .all()
        
        var users = [User]()
        
        for participant in participants {
            if let roomUser = try await User.query(on: req.db)
                .filter(\.$id == participant.userID)
                .first() {
                users.append(roomUser)
            }
        }
        
        var teams = [Team]()
        
        for participant in participants {
            if let teamId = participant.teamID,
               let team = try await Team.query(on: req.db)
                .filter(\.$id == teamId)
                .first() {
                teams.append(team)
            }
        }
        
        var usersInGame = [UserInGame]()
        
        for participant in participants {
            let id = try participant.requireID()
            let name = users.first(where: { $0.id == participant.userID })?.nickname ?? ""
            let teamId = participant.teamID
            var team: String?
            if let teamId = teamId {
                team = try teams.first(where: { try $0.requireID() == teamId})?.name
            }
            usersInGame.append(.init(id: id, name: name, teamId: teamId, team: team))
        }
    
        let roomTeams = try await Team.query(on: req.db)
                   .filter(\.$roomID == roomId)
                   .all()
        
        return GetRoomInfoResponse(name: room.name,
                                   id: roomId,
                                   participants: usersInGame,
                                   teams: roomTeams,
                                   url: room.url,
                                   isAdmin: room.adminId == user,
                                   key: room.inviteCode)
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
    
    func deleteTeam(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let deleteReq = try req.content.decode(DeleteRoomRequest.self)
        
        guard let team = try await Team.find(deleteReq.id, on: req.db)
        else {
            return .badRequest
        }
        
        let participant = try await Participant.query(on: req.db)
            .filter(\.$teamID == deleteReq.id)
            .all()
        
        for item in participant {
            item.teamID = nil
            try await item.update(on: req.db)
        }
        
        try await team.delete(on: req.db)
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
    
    func startGame(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let startGameRequest = try req.content.decode(StartGameRequest.self)
        
        guard let room = try await Room.query(on: req.db)
            .filter(\.$adminId == user)
            .first() else {
            throw Abort(.notFound)
        }
        
        room.numberOfRounds = startGameRequest.numberOfRounds
        try await room.update(on: req.db)
        
        let participants = try await Participant.query(on: req.db)
            .filter(\.$roomID == room.requireID())
            .all()
        
        let participantsId = participants.filter { $0.teamID != nil }.compactMap { $0.userID }
        
        
        WebsocketManager.shared.send(message: "start", receivers: participantsId)
        
        return .ok
    }
    
    func nextRound(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let nextRoundRequest = try req.content.decode(NextRoundRequest.self)
        
        
        guard let roomID = try await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first()?.roomID else {
            throw Abort(.notFound)
        }
        
        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomID)
            .first() else {
            return .notFound
        }

        let participantOfGame = try await Participant.query(on: req.db)
            .filter(\.$roomID == roomID)
            .all()

        var teamSizes = [UUID: Int]()

        try participantOfGame.forEach {
            guard let teamId = $0.teamID else {
                throw Abort(.badRequest)
            }

            if teamSizes.keys.contains(teamId) {
                teamSizes[teamId]! += 1
            }
            else {
                teamSizes[teamId] = 1
            }
        }

        let maxTeamSize = teamSizes.max(by: { (el1, el2) in
            el1.value < el2.value
        })?.value

        guard let maxTeamSize = maxTeamSize else {
            return .badRequest
        }

        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first() else {
            throw Abort(.notFound)
        }

        guard let teamId = participant.teamID else {
            throw Abort(.badRequest)
        }

        let teamMembers = try await Participant.query(on: req.db)
            .filter(\.$teamID == teamId)
            .all()

        var teamMembersIds = [UUID]()

        for user in teamMembers {
            teamMembersIds.append(user.userID)
        }

        guard let team = try await Team.query(on: req.db)
            .filter(\.$id == teamId)
            .first() else {
            throw Abort(.badRequest)
        }
        
        if nextRoundRequest.points != -1 {
            team.totalPoints += nextRoundRequest.points
            team.round += 1
        }

        if team.round % maxTeamSize == 0 {
            if team.round / maxTeamSize == room.numberOfRounds {
                let teams = try await Team.query(on: req.db)
                    .filter(\.$roomID == roomID)
                    .all()
                
                let teamsRounds = teams.map { $0.round / maxTeamSize == room.numberOfRounds }
                
                for bool in teamsRounds {
                    if !bool {
                        WebsocketManager.shared.send(message: "waitForResults", receivers: teamMembersIds)
                        return .ok
                    }
                }
                
                var sortedTeams = teams.sorted(by: { team1, team2 in
                    team1.totalPoints < team2.totalPoints
                })
                
                guard !sortedTeams.isEmpty else {
                    return .badRequest
                }
                
                let winners = try await Participant.query(on: req.db)
                    .filter(\.$teamID == sortedTeams[0].requireID())
                    .all()
                
                let winnersIds = try winners.map { try $0.requireID() }
                
                sortedTeams.remove(at: 0)
                let otherTeamsIds = try sortedTeams.map { try $0.requireID() }
                
                var others = [UUID]()
                try participantOfGame.forEach { part in
                    if let partTeamID = part.teamID {
                        if otherTeamsIds.contains(partTeamID) {
                            try others.append(part.requireID())
                        }
                    }
                }
                
                WebsocketManager.shared.send(message: "You win", receivers: winnersIds)
                WebsocketManager.shared.send(message: "You lose", receivers: others)
                
                return .ok
            }
        }

        try await team.update(on: req.db)

        let activeUser = teamMembersIds[team.round % maxTeamSize]
        
        teamMembersIds.remove(at: team.round % maxTeamSize)

        try WebsocketManager.shared.sendWords(activeUser: activeUser, waiting: teamMembersIds)
        return .ok
    }
    
}

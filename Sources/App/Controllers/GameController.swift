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
        gameRoutes.put("endGame", use: endGame)
        gameRoutes.delete("deleteProfile", use: deleteProfile)
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
    
    func changeRoomState(req: Request) async throws -> ChangeRoomStateResponse {
        let user = try await TokenHelpers.getUserID(req: req)
        let roomModel = try req.content.decode(ChangeRoomStateRequest.self)
        
        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomModel.roomID)
            .filter(\.$adminId == user)
            .first()
        else {
            throw Abort(.notFound)
        }
        
        room.isOpen = roomModel.isOpen
        room.inviteCode = roomModel.isOpen ? nil : String.randomString(length: 20)
        try await room.update(on: req.db)
        return ChangeRoomStateResponse(inviteCode: room.inviteCode)
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
    
    func deleteProfile(req: Request) async throws -> HTTPStatus {
        let userUIID = try await TokenHelpers.getUserID(req: req)
        
        guard let user = try await User.find(userUIID, on: req.db) else {
            return .badRequest
        }
        
        
        let room = try await Room.query(on: req.db)
            .filter(\.$adminId == user.requireID())
            .all()
        
        
        for r in room {
            let participant = try await Participant.query(on: req.db)
                .filter(\.$roomID == r.requireID())
                .all()
            
            for p in participant {
                try await p.delete(on: req.db)
            }
            
            let teams = try await Team.query(on: req.db)
                .filter(\.$roomID == r.requireID())
                .all()
            
            for t in teams {
                try await t.delete(on: req.db)
            }
            
            
        }
        
        for r in room {
            try await r.delete(on: req.db)
        }
        
        let participantMe = try await Participant.query(on: req.db)
            .filter(\.$userID == user.requireID())
            .all()
        
        for me in participantMe {
            try await me.delete(on: req.db)
        }
        
        try await user.delete(on: req.db)
        
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
            .filter(\.$id == passReq.userID)
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
        
        guard let participant = try await Participant.find(addToTeamReq.userID, on: req.db)
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
        
        guard let room = try await Room.find(startGameRequest.roomID, on: req.db)
        else {
            return .notFound
        }
        
        if room.adminId != user {
            return .notFound
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
    
    func endGame(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let deleteReq = try req.content.decode(EndGame.self)
        
        guard let room = try await Room.find(deleteReq.roomID, on: req.db),
              room.adminId == user
        else {
            return .badRequest
        }
        
        let teams = try await Team.query(on: req.db)
            .filter(\.$roomID == room.requireID())
            .all()
        
        for t in teams {
            t.totalPoints = 0
            t.round = 0
            try await t.update(on: req.db)
        }
        
        return .ok
    }
    
    func nextRound(req: Request) async throws -> HTTPStatus {
        let user = try await TokenHelpers.getUserID(req: req)
        let nextRoundRequest = try req.content.decode(NextRoundRequest.self)
        
        // Находим id нашей комнату
        let roomID = nextRoundRequest.roomID
        
        // Находим комнату
        guard let room = try await Room.query(on: req.db)
            .filter(\.$id == roomID)
            .first() else {
            return .notFound
        }
        
        // Находим участников игры
        let participantOfGame = try await Participant.query(on: req.db)
            .filter(\.$roomID == roomID)
            .all()
        
        // Находим максимальный размер команды
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
        
        
        // Ищем участника отправившего запрос
        guard let participant = try await Participant.query(on: req.db)
            .filter(\.$userID == user)
            .first() else {
            throw Abort(.notFound)
        }
        
        // Ищем id его команды
        guard let teamId = participant.teamID else {
            throw Abort(.badRequest)
        }
        
        
        // Ищем его сокомандников
        let teamMembers = try await Participant.query(on: req.db)
            .filter(\.$teamID == teamId)
            .all()
        
        
        // Ищем id его сокомандников
        var teamMembersIds = [UUID]()
        
        for user in teamMembers {
            teamMembersIds.append(user.userID)
        }
        
        // Ищем команда нашего пользователя
        guard let team = try await Team.query(on: req.db)
            .filter(\.$id == teamId)
            .first() else {
            throw Abort(.badRequest)
        }
        
        
        // Увеличиваем очки и раунд команды, если чел прислал их
        if nextRoundRequest.points != -1 {
            team.totalPoints += nextRoundRequest.points
            team.round += 1
            try await team.update(on: req.db)
        }
        
        // Проверка конца игры или конца круга
        if team.round % maxTeamSize == 0 && nextRoundRequest.points != -1 {
            if team.round / maxTeamSize == room.numberOfRounds {
                
                // Ищем все команды игры
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
                
                // Сортировка по очкам
                var sortedTeams = teams.sorted(by: { team1, team2 in
                    team1.totalPoints > team2.totalPoints
                })
                
                
                guard !sortedTeams.isEmpty else {
                    return .badRequest
                }
                
                // Ищем победителей
                let winners = try await Participant.query(on: req.db)
                    .filter(\.$teamID == sortedTeams[0].requireID())
                    .all()
                
                // Ids команды победителя
                let winnersIds = winners.map { $0.userID }
                
                
                // Ids проигравших команд
                sortedTeams.remove(at: 0)
                let otherTeamsIds = try sortedTeams.map { try $0.requireID() }
                
                // ids проигравших
                var others = [UUID]()
                participantOfGame.forEach { part in
                    if let partTeamID = part.teamID {
                        if otherTeamsIds.contains(partTeamID) {
                            others.append(part.userID)
                        }
                    }
                }
                
                WebsocketManager.shared.send(message: "You win", receivers: winnersIds)
                WebsocketManager.shared.send(message: "You lose", receivers: others)
                return .ok
                
            }
        }
        
        let activeUser = teamMembersIds[team.round % maxTeamSize]
        teamMembersIds.remove(at: team.round % maxTeamSize)
            
        try WebsocketManager.shared.sendWords(activeUser: activeUser, waiting: teamMembersIds)
        return .ok
    }
    
}

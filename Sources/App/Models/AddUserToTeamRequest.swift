import Vapor

struct AddUserToTeamRequest: Content {
    let userID: UUID
    let teamID: UUID
}

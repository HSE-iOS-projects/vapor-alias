import Vapor

struct AddUserToTeamRequest: Content {
    let userID: UUID
    let roomID: UUID
}

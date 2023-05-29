import Vapor
import Fluent

final class Room: Content, Model {

    static let schema = "rooms"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "admin_id")
    var adminId: UUID

    @Field(key: "name")
    var name: String

    @Field(key: "url")
    var url: String

    @Field(key: "is_open")
    var isOpen: Bool

    @Field(key: "invite_code")
    var inviteCode: String?

    @Field(key: "status")
    var status: String

    init() { }

    init(id: UUID? = nil, adminId: UUID, name: String, url: String, isOpen: Bool, inviteCode: String?, status: String) {
        self.id = id
        self.adminId = adminId
        self.name = name
        self.url = url
        self.isOpen = isOpen
        self.inviteCode = inviteCode
        self.status = status
    }

}

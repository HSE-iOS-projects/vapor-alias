import Vapor
import Fluent

final class User: Model, Content {

    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "nickname")
    var nickname: String

    @Field(key: "password")
    var password: String

    init() { }

    init(id: UUID? = nil, nickname: String, password: String) {
        self.id = id
        self.nickname = nickname
        self.password = password
    }
    
}

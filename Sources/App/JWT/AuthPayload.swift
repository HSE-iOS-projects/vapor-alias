import JWT

struct AuthPayload: JWTPayload {
    var subject: SubjectClaim
    var expirationTime: ExpirationClaim

    init(subject: String, expirationTime: Date) {
        self.subject = SubjectClaim(value: subject)
        self.expirationTime = ExpirationClaim(value: expirationTime)
    }

    func verify(using signer: JWTSigner) throws {
        try self.expirationTime.verifyNotExpired()
    }
}

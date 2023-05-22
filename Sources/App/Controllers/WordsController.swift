import Fluent
import Vapor

struct WordsController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let wordsRoutes = routes.grouped("words")
        wordsRoutes.group(":number") { room in
            room.get(use: getWords)
        }
    }

    func getWords(req: Request) async throws -> Words {
        let _ = try await TokenHelpers.getUserID(req: req)

        guard let strNum = req.parameters.get("number"), let num = Int(strNum) else {
            throw Abort(.badRequest)
        }

        let words = WordsProvider.getRandomWords(num: num)
        let wordsResponse = Words(words: words)
        return wordsResponse
    }

}


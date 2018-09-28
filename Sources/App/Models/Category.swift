import Vapor
import FluentPostgreSQL

final class Category: Codable {
    var id: Int?
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

// MARK: - Conforms
extension Category: PostgreSQLModel {}

extension Category: Migration {}

extension Category: Content {}

extension Category: Parameter {}

// MARK: - Relationships
extension Category {
    var acronyms: Siblings<Category, Acronym, AcronymCategoryPivot> {
        return siblings()
    }
}

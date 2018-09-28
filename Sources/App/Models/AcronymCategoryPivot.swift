import FluentPostgreSQL

final class AcronymCategoryPivot: PostgreSQLUUIDPivot, ModifiablePivot {
    
    typealias Left = Acronym
    typealias Right = Category
    
    static var leftIDKey: LeftIDKey = \.acronymID
    static var rightIDKey: RightIDKey = \.categoryID
    
    var id: UUID?
    var acronymID: Acronym.ID
    var categoryID: Category.ID
    
    init(_ acronym: Acronym, _ category: Category) throws {
        self.acronymID = try acronym.requireID()
        self.categoryID = try category.requireID()
    }
    
}

// MARK: - Conforms
extension AcronymCategoryPivot: Migration {}

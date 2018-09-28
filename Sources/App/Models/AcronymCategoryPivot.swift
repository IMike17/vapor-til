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
extension AcronymCategoryPivot: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database
            .create(self, on: connection,
                    closure: { (builder) in
                        try addProperties(to: builder)
                        
                        builder.reference(
                            from: \.acronymID,
                            to: \Acronym.id,
                            onDelete: .restrict)
                        
                        builder.reference(
                            from: \.categoryID,
                            to: \Category.id,
                            onDelete: .restrict)
            })
    }
}

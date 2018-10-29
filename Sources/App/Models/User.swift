import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
	var password: String
    
    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
		self.password = password
    }
	
	final class Public: Codable {
		var id: UUID?
		var name: String
		var username: String
		
		init(id: UUID?, name: String, username: String) {
			self.id = id
			self.name = name
			self.username = username
		}
	}
}

// MARK: - Conforms
extension User: Content {}

extension User: Migration {
	static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
		return Database.create(self, on: connection) { builder in
			try addProperties(to: builder)
			builder.unique(on: \.username)
		}
	}
}

extension User: Parameter {}

extension User: PostgreSQLUUIDModel {}

// MARK: - Authentication
extension User: BasicAuthenticatable {
	static let usernameKey: UsernameKey = \User.username
	static let passwordKey: PasswordKey = \User.password
}

// MARK: - Public
extension User.Public: Content {}

extension User {
	func convertToPublic() -> User.Public {
		return User.Public(id: id, name: name, username: username)
	}
}

extension Future where T: User {
	func convertToPublic() -> Future<User.Public> {
		return self.map(to: User.Public.self) { user in
			return user.convertToPublic()
		}
	}
}

// MARK: - Relationships
extension User {
    var acronyms: Children<User, Acronym> {
        return children(\.userID)
    }
}


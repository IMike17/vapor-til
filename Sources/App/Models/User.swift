import Vapor
import FluentPostgreSQL
import Authentication

final class User: Codable {
	var id: UUID?
	var name: String
	var username: String
	var password: String
	var twitterURL: String?
	
	init(name: String, username: String, password: String, twitterURL: String? = nil) {
		self.name = name
		self.username = username
		self.password = password
		self.twitterURL = twitterURL
	}
	
	final class Public: Codable {
		var id: UUID?
		var name: String
		var username: String
		var twitterURL: String?
		
		init(id: UUID?, name: String, username: String, twitterURL: String? = nil) {
			self.id = id
			self.name = name
			self.username = username
			self.twitterURL = twitterURL
		}
	}
}

// MARK: - Conforms
extension User: Content {}

extension User: Migration {
	static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
		return Database.create(self, on: connection) { builder in
			builder.field(for: \.id, isIdentifier: true)
			builder.field(for: \.name)
			builder.field(for: \.username)
			builder.field(for: \.password)
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

extension User: PasswordAuthenticatable {}

extension User: SessionAuthenticatable {}

extension User: TokenAuthenticatable {
	typealias TokenType = Token
}

// MARK: - Public
extension User.Public: Content {}

extension User {
	func convertToPublic() -> User.Public {
		return User.Public(id: id, name: name, username: username, twitterURL: twitterURL)
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


// MARK: - Seed
struct AdminUser: Migration {
	typealias Database = PostgreSQLDatabase
	
	static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
		let password = try? BCrypt.hash("password")
		guard let hashedPassword = password else {
			fatalError("Failed to create admin user")
		}
		
		let user = User(
			name: "Admin",
			username: "admin",
			password: hashedPassword)
		
		return user.save(on: conn).transform(to: ())
	}
	
	static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
		return Future.done(on: conn)
	}
}

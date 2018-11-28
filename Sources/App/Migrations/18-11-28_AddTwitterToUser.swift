import FluentPostgreSQL
import Vapor

struct AddTwitterURLToUser: Migration {
	typealias Database = PostgreSQLDatabase
	
	static func prepare(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
		return Database.update(
			User.self,
			on: conn,
			closure: { builder in
				builder.field(for: \.twitterURL)
		})
	}
	
	static func revert(on conn: PostgreSQLConnection) -> EventLoopFuture<Void> {
		return Database.update(
			User.self,
			on: conn,
			closure: { builder in
				builder.deleteField(for: \.twitterURL)
		})
	}
}

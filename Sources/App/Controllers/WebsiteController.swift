import Vapor
import Leaf

struct WebsiteController: RouteCollection {
	func boot(router: Router) throws {
		router.get(use: indexHandler)
		router.get("acronyms", Acronym.parameter, use: acronymHandler)
		router.get("users", User.parameter, use: userHandler)
	}
	
	func indexHandler(_ req: Request) throws -> Future<View> {
		return Acronym.query(on: req)
			.all()
			.flatMap(to: View.self, { acronyms in
				let acronymsData = acronyms.isEmpty ? nil : acronyms
				let context = IndexContext(title: "Homepage", acronyms: acronymsData)
				return try req.view().render("index", context)
			})
	}
	
	func acronymHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(Acronym.self)
			.flatMap(to: View.self, { acronym in
				return acronym.user
					.get(on: req)
					.flatMap(to: View.self, { user in
						let context = AcronymContext(
							title: acronym.short,
							acronym: acronym,
							user: user)
						
						return try req.view().render("acronym", context)
					})
			})
	}
	
	func userHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(User.self)
			.flatMap(to: View.self, { user in
				return try user.acronyms
					.query(on: req)
					.all()
					.flatMap(to: View.self, { acronyms in
						let contex = UserContext(
							title: user.name,
							user: user,
							acronyms: acronyms)
						
						return try req.view().render("user", contex)
					})
			})
	}
}

struct AcronymContext: Encodable {
	let title: String
	let acronym: Acronym
	let user: User
}

struct IndexContext: Encodable {
	let title: String
	let acronyms: [Acronym]?
}

struct UserContext: Encodable {
	let title: String
	let user: User
	let acronyms: [Acronym]
}

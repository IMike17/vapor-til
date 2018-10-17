import Vapor
import Leaf

struct WebsiteController: RouteCollection {
	func boot(router: Router) throws {
		router.get("acronyms", Acronym.parameter, use: self.acronymHandler)
		router.get("acronyms", "create", use: self.createAcronymHandler)
		router.post(Acronym.self, at: "acronyms", "create", use: self.createAcronymPostHandler)
		router.post("acronyms", Acronym.parameter, "delete", use: self.deleteAcronymHandler)
		router.get("acronyms", Acronym.parameter, "edit", use: self.editAcronymHandler)
		router.post("acronyms", Acronym.parameter, "edit", use: self.editAcronymPostHandler)
		router.get("categories", use: self.allCategoriesHandler)
		router.get("categories", Category.parameter, use: self.categoryHandler)
		router.get(use: indexHandler)
		router.get("users", use: self.allUsersHandler)
		router.get("users", User.parameter, use: self.userHandler)
	}
	
	// MARK: - Handlers
	
	// MARK: - Acronym Handlers
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
	
	func createAcronymHandler(_ req: Request) throws -> Future<View> {
		let context = CreateAcronymContext(
			users: User.query(on: req).all())
		
		return try req.view().render("createAcronym", context)
	}
	
	func createAcronymPostHandler(_ req: Request, acronym: Acronym) throws -> Future<Response> {
		return acronym.save(on: req)
			.map(to: Response.self, { acronym in
				guard let id = acronym.id else {
					throw Abort(HTTPResponseStatus.internalServerError)
				}
				
				return req.redirect(to: "/acronyms/\(id)")
			})
	}
	
	func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
		return try req.parameters.next(Acronym.self)
			.delete(on: req)
			.transform(to: req.redirect(to: "/"))
	}
	
	func editAcronymHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(Acronym.self)
			.flatMap(to: View.self, { acronym in
				let context = EditAcronymContext(
					acronym: acronym,
					users: User.query(on: req).all())
				
				return try req.view().render("createAcronym", context)
			})
		
	}
	
	func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
		return try flatMap(
			to: Response.self,
			req.parameters.next(Acronym.self),
			req.content.decode(Acronym.self),
			{ dbAcronym, newAcronym in
				dbAcronym.short = newAcronym.short
				dbAcronym.long = newAcronym.long
				dbAcronym.userID = newAcronym.userID
				
				return dbAcronym.save(on: req)
					.map(to: Response.self, { acronym in
						guard let id = acronym.id else {
							throw Abort(HTTPResponseStatus.internalServerError)
						}
						
						return req.redirect(to: "/acronyms/\(id)")
					})
		})
	}
	
	// MARK: - Category Handlers
	func allCategoriesHandler(_ req: Request) throws -> Future<View> {
		let categories = Category.query(on: req).all()
		let context = AllCategoriesContext(categories: categories)
		
		return try req.view().render("allCategories", context)
	}
	
	func categoryHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(Category.self)
			.flatMap(to: View.self, { category in
				let acronyms = try category.acronyms
					.query(on: req)
					.all()
				let context = CategoryContext(
					title: category.name,
					category: category,
					acronyms: acronyms)
				
				return try req.view().render("category", context)
			})
	}
	
	// MARK: - Index Handlers
	func indexHandler(_ req: Request) throws -> Future<View> {
		return Acronym.query(on: req)
			.all()
			.flatMap(to: View.self, { acronyms in
				let acronymsData = acronyms.isEmpty ? nil : acronyms
				let context = IndexContext(title: "Homepage", acronyms: acronymsData)
				return try req.view().render("index", context)
			})
	}
	
	// MARK: - User Handlers
	func allUsersHandler(_ req: Request) throws -> Future<View> {
		return User.query(on: req)
			.all()
			.flatMap(to: View.self, { users in
				let context = AllUsersContext(
					title: "All Users",
					users: users)
				
				return try req.view().render("allUsers", context)
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

// MARK: - Contexts

// MARK: - Acronym
struct AcronymContext: Encodable {
	let title: String
	let acronym: Acronym
	let user: User
}

struct CreateAcronymContext: Encodable {
	let title = "Create An Acronym"
	let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
	let title = "Edit Acronym"
	let acronym: Acronym
	let users: Future<[User]>
	let editing = true
}

// MARK: - Category
struct AllCategoriesContext: Encodable {
	let title = "All Categories"
	let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
	let title: String
	let category: Category
	let acronyms: Future<[Acronym]>
}

// MARK: - Index
struct IndexContext: Encodable {
	let title: String
	let acronyms: [Acronym]?
}

// MARK: - User
struct AllUsersContext: Encodable {
	let title: String
	let users: [User]
}

struct UserContext: Encodable {
	let title: String
	let user: User
	let acronyms: [Acronym]
}

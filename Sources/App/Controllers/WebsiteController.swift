import Vapor
import Leaf
import Fluent
import Authentication

struct WebsiteController: RouteCollection {
	func boot(router: Router) throws {
		// MARK: Public
		let authSessionRoutes = router.grouped(User.authSessionsMiddleware())
		authSessionRoutes.get("acronyms", Acronym.parameter, use: acronymHandler)
		authSessionRoutes.get("categories", use: allCategoriesHandler)
		authSessionRoutes.get("categories", Category.parameter, use: categoryHandler)
		authSessionRoutes.get(use: indexHandler)
		authSessionRoutes.get("login", use: loginHandler)
		authSessionRoutes.post(LoginPostData.self, at:"login", use: loginPostHandler)
		authSessionRoutes.post("logout", use: logoutHandler)
		authSessionRoutes.get("users", use: allUsersHandler)
		authSessionRoutes.get("users", User.parameter, use: userHandler)
		
		// MARK: Secure
		let protectedRoutes = authSessionRoutes.grouped(RedirectMiddleware<User>(path: "/login"))
		protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
		protectedRoutes.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
		protectedRoutes.post(DeleteAcronymData.self, at: "acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
		protectedRoutes.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
		protectedRoutes.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
	}
	
	// MARK: - Handlers
	
	// MARK: - Acronym Handlers
	func acronymHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(Acronym.self)
			.flatMap(to: View.self, { acronym in
				return acronym.user
					.get(on: req)
					.flatMap(to: View.self, { user in
						let categories = try acronym.categories.query(on: req).all()
						let token = try CryptoRandom()
							.generateData(count: 16)
							.base64EncodedString()
						try req.session()["CSRF_TOKEN"] = token
						
						let context = AcronymContext(
							title: acronym.short,
							acronym: acronym,
							user: user,
							categories: categories,
							csrfToken: token)
						
						return try req.view().render("acronym", context)
					})
			})
	}
	
	func createAcronymHandler(_ req: Request) throws -> Future<View> {
		let token = try CryptoRandom()
			.generateData(count: 16)
			.base64EncodedString()
		let context = CreateAcronymContext(csrfToken: token)
		try req.session()["CSRF_TOKEN"] = token
		
		return try req.view().render("createAcronym", context)
	}
	
	func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
		let expectedToken = try req.session()["CSRF_TOKEN"]
		try req.session()["CSRF_TOKEN"] = nil
		
		guard expectedToken == data.csrfToken else {
			throw Abort(.badRequest)
		}
		
		let user = try req.requireAuthenticated(User.self)
		let acronym = try Acronym(
			short: data.short,
			long: data.long,
			userID: user.requireID())
		
		return acronym.save(on: req)
			.flatMap(to: Response.self, { acronym in
				guard let id = acronym.id else {
					throw Abort(HTTPResponseStatus.internalServerError)
				}
				
				var categorySaves: [Future<Void>] = []
				
				for category in data.categories ?? [] {
					categorySaves.append(Category.addCategory(category, to: acronym, on: req))
				}
				
				let redirect = req.redirect(to: "/acronyms/\(id)")
				
				return categorySaves.flatten(on: req)
					.transform(to: redirect)
			})
	}
	
	func deleteAcronymHandler(_ req: Request, data: DeleteAcronymData) throws -> Future<Response> {
		let expectedToken = try req.session()["CSRF_TOKEN"]
		try req.session()["CSRF_TOKEN"] = nil

		guard expectedToken == data.csrfToken else {
			throw Abort(.badRequest)
		}
		return try req.parameters.next(Acronym.self).delete(on: req).transform(to: req.redirect(to: "/"))
	}
	
	func editAcronymHandler(_ req: Request) throws -> Future<View> {
		return try req.parameters.next(Acronym.self)
			.flatMap(to: View.self, { acronym in
				let categories = try acronym.categories.query(on: req).all()
				let token = try CryptoRandom()
					.generateData(count: 16)
					.base64EncodedString()
				try req.session()["CSRF_TOKEN"] = token
				let context = EditAcronymContext(
					acronym: acronym,
					categories: categories,
					csrfToken: token)
				
				return try req.view().render("createAcronym", context)
			})
		
	}
	
	func editAcronymPostHandler(_ req: Request) throws -> Future<Response> {
		return try flatMap(
			to: Response.self,
			req.parameters.next(Acronym.self),
			req.content.decode(CreateAcronymData.self),
			{ acronym, data in
				let expectedToken = try req.session()["CSRF_TOKEN"]
				try req.session()["CSRF_TOKEN"] = nil
				
				guard expectedToken == data.csrfToken else {
					throw Abort(.badRequest)
				}
				let user = try req.requireAuthenticated(User.self)
				acronym.short = data.short
				acronym.long = data.long
				try acronym.userID = user.requireID()
				
				return acronym.save(on: req)
					.flatMap(to: Response.self, { acronym in
						guard let id = acronym.id else {
							throw Abort(HTTPResponseStatus.internalServerError)
						}
						
						return try acronym.categories.query(on: req)
							.all()
							.flatMap(to: Response.self, { existingCategories in
								let existingStringArray = existingCategories.map{ $0.name }
								
								let existingSet = Set<String>(existingStringArray)
								let newSet = Set<String>(data.categories ?? [])
								
								let categoriesToAdd = newSet.subtracting(existingSet)
								let categoriesToRemove = existingSet.subtracting(newSet)
								
								var categoryResults: [Future<Void>] = []
								
								for newCategory in categoriesToAdd {
									categoryResults.append(
										Category.addCategory(
											newCategory,
											to: acronym,
											on: req)
									)
								}
								
								for categoryNameToRemove in categoriesToRemove {
									guard let categoryToRemove = (existingCategories.first {
										$0.name == categoryNameToRemove
									}) else {
										continue
									}
									
									categoryResults.append(
										acronym.categories.detach(categoryToRemove, on: req)
									)
								}
								
								return categoryResults
									.flatten(on: req)
									.transform(to: req.redirect(to: "/acronyms/\(id)"))
							})
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
				let userLoggedIn = try req.isAuthenticated(User.self)
				let showCookieMessage = req.http.cookies["cookies-accepted"] == nil
				let context = IndexContext(
					title: "Homepage",
					acronyms: acronymsData,
					userLoggedIn: userLoggedIn,
					showCookieMessage: showCookieMessage)
				return try req.view().render("index", context)
			})
	}
	
	// MARK: - Login Handlers
	func loginHandler(_ req: Request) throws -> Future<View> {
		let token = try CryptoRandom()
			.generateData(count: 16)
			.base64EncodedString()
		try req.session()["CSRF_TOKEN"] = token
		
		let context: LoginContext
		
		if req.query[Bool.self, at: "error"] != nil {
			context = LoginContext(csrfToken: token, loginError: true)
		} else {
			context = LoginContext(csrfToken: token)
		}
		
		return try req.view().render("login", context)
	}
	
	func loginPostHandler(_ req: Request, userData: LoginPostData) throws -> Future<Response> {
		let expectedToken = try req.session()["CSRF_TOKEN"]
		try req.session()["CSRF_TOKEN"] = nil
		
		guard expectedToken == userData.csrfToken else {
			throw Abort(.badRequest)
		}
		
		return User.authenticate(
			username: userData.username,
			password: userData.password,
			using: BCryptDigest(),
			on: req)
			.map(to: Response.self) { user in
				guard let user = user else {
					return req.redirect(to: "/login?error")
				}
				
				try req.authenticateSession(user)
				
				return req.redirect(to: "/")
		}
	}
	
	// MARK: - Logout Handlers
	func logoutHandler(_ req: Request) throws -> Response {
		try req.unauthenticateSession(User.self)
		return req.redirect(to: "/")
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
	let categories: Future<[Category]>
	let csrfToken: String
}

struct CreateAcronymContext: Encodable {
	let title = "Create An Acronym"
	let csrfToken: String
}

struct CreateAcronymData: Content {
	let short: String
	let long: String
	let categories: [String]?
	let csrfToken: String
}

struct EditAcronymContext: Encodable {
	let title = "Edit Acronym"
	let acronym: Acronym
	let categories: Future<[Category]>
	let editing = true
	let csrfToken: String
}

struct DeleteAcronymData: Content {
	let csrfToken: String
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
	let userLoggedIn: Bool
	let showCookieMessage: Bool
}

// MARK: - Login
struct LoginContext: Encodable {
	let title = "Log In"
	let loginError: Bool
	let csrfToken: String
	
	init(csrfToken: String, loginError: Bool = false) {
		self.loginError = loginError
		self.csrfToken = csrfToken
	}
}

struct LoginPostData: Content {
	let username: String
	let password: String
	let csrfToken: String
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

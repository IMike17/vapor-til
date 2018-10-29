import Vapor
import Fluent
import Authentication

struct AcronymsController: RouteCollection {
    func boot(router: Router) {
		
		// MARK: Public
        let acronymsRoutes = router.grouped("api", "acronyms")
        acronymsRoutes.get(use: getAllHandler)
        acronymsRoutes.get(Acronym.parameter, use: getHandler)
        acronymsRoutes.get(Acronym.parameter, "categories", use: getCategoriesHandler)
        acronymsRoutes.get(Acronym.parameter, "user", use: getUserHandler)
        acronymsRoutes.get("search", use: searchHandler)
        acronymsRoutes.get("first", use: getFirstHandler)
        acronymsRoutes.get("sorted", use: sortedHandler)
		
		// MARK: Secure
		let tokenAuthMiddleware = User.tokenAuthMiddleware()
		let guardAuthMiddleware = User.guardAuthMiddleware()
		
		let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
		tokenAuthGroup.post(AcronymCreateData.self, use: createHandler)
		tokenAuthGroup.put(Acronym.parameter, use: updateHanlder)
		tokenAuthGroup.delete(Acronym.parameter, use: deleteHandler)
		tokenAuthGroup.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
		tokenAuthGroup.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
    }

    //MARK: - /acronyms
    //MARK: GET
    func getAllHandler(_ req: Request) -> Future<[Acronym]> {
        return Acronym.query(on: req)
            .all()
    }
    
    //MARK: POST
    func createHandler(_ req: Request, data: AcronymCreateData) throws -> Future<Acronym> {
		let user = try req.requireAuthenticated(User.self)
		
		let acronym = try Acronym(
			short: data.short,
			long: data.long,
			userID: user.requireID())
		
        return acronym.save(on: req)
    }
    
    //MARK: - /acronyms/{id}
    //MARK: GET
    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }
    
    //MARK: PUT
    func updateHanlder(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(
            to: Acronym.self,
            req.parameters.next(Acronym.self),
            req.content.decode(AcronymCreateData.self),
            { (dbAcronym, requestAcronym) -> Future<Acronym> in
                dbAcronym.short = requestAcronym.short
                dbAcronym.long = requestAcronym.long
				
				let user = try req.requireAuthenticated(User.self)
                dbAcronym.userID = try user.requireID()
				
                return dbAcronym.save(on: req)
        })
    }
    
    //MARK: DELETE
    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(Acronym.self)
            .delete(on: req)
            .transform(to: HTTPStatus.noContent)
    }
    
    //MARK: - /acronyms/{id}/categories
    //MARK: GET
    func getCategoriesHandler(_ req: Request) throws -> Future<[Category]>{
        return try req.parameters.next(Acronym.self)
            .flatMap(to: [Category].self,
                     { (acronym) in
                        return try acronym.categories.query(on: req).all()
            })
    }
    
    //MARK: - /acronyms/{id}/categories/{id}
    //MARK: POST
    func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(
            to: HTTPStatus.self,
            req.parameters.next(Acronym.self),
            req.parameters.next(Category.self),
            { (acronym, category) -> Future<HTTPStatus> in
                return acronym.categories
                    .attach(category, on: req)
                    .transform(to: HTTPStatus.created)
        })
    }
    
    //MARK: DELETE
    func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(
            to: HTTPStatus.self,
            req.parameters.next(Acronym.self),
            req.parameters.next(Category.self),
            { (acronym, category) -> Future<HTTPStatus> in
                return acronym.categories
                    .detach(category, on: req)
                    .transform(to: HTTPStatus.noContent)
        })
    }
    
    //MARK: - /acronyms/{id}/user
    //MARK: GET
    /// Get the User that owns the {id} acronym
    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(Acronym.self)
            .flatMap(to: User.Public.self,
                     { acronym in
                        return acronym.user.get(on: req)
							.convertToPublic()
            })
    }
    
    //MARK: - /acronyms/first
    /// Searches first acronym in the DB
    func getFirstHandler(_ req: Request) -> Future<Acronym> {
        return Acronym
            .query(on: req)
            .first()
            .map(to: Acronym.self,
                 { (acronym) -> Acronym in
                    guard let acronym = acronym else {
                        throw Abort(HTTPResponseStatus.notFound)
                    }
                    
                    return acronym
            })
    }
    
    //MARK: - /acronyms/search
    /// Searches acronyms from a search term
    ///
    /// - parameters:
    ///     - term: The search term.
    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else {
            throw Abort(HTTPResponseStatus.badRequest)
        }
        
        return Acronym.query(on: req)
            .group(.or, closure: { (or) in
                or.filter(\.short == searchTerm)
                
                or.filter(\.long == searchTerm)
            })
            .all()
    }
    
    //MARK: - /acronyms/sorted
    /// Sorts all the acronyms in the DB
    func sortedHandler(_ req: Request) -> Future<[Acronym]> {
        return Acronym
            .query(on: req)
            .sort(\.short, .ascending)
            .all()
    }
}

// MARK: - Content
struct AcronymCreateData: Content {
	let short: String
	let long: String
}

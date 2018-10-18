import Vapor
import Crypto

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        
        usersRoute.get(use: getAllHandler)
        usersRoute.post(User.self, use: createHandler)
        usersRoute.get(User.parameter, use: getHandler)
        usersRoute.get(User.parameter, "acronyms", use: getAcronymsHandler)
    }
    
    //MARK: - /users
    //MARK: GET
    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req)
			.decode(data: User.Public.self)
			.all()
    }
    
    //MARK: POST
    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
		user.password = try BCrypt.hash(user.password)
		
		return user.save(on: req)
			.convertToPublic()
    }
    
    //MARK: - /users/{id}
    //MARK: GET
    func getHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self)
			.convertToPublic()
    }
    
    //MARK: - /users/{id}/acronyms
    //MARK: GET
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(User.self)
            .flatMap(to: [Acronym].self, { (user) in
                try user.acronyms.query(on: req).all()
            })
    }
}

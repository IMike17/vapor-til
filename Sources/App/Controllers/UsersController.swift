import Vapor

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let usersRoute = router.grouped("api", "users")
        
        usersRoute.get(use: getAllHandler)
        usersRoute.post(User.self, use: createHandler)
        usersRoute.get(User.parameter, use: getHandler)
    }
    
    //MARK: - /users
    //MARK: GET
    func getAllHandler(_ req: Request) throws -> Future<[User]> {
        return User.query(on: req).all()
    }
    
    //MARK: POST
    func createHandler(_ req: Request, user: User) throws -> Future<User> {
        return user.save(on: req)
    }
    
    //MARK: - /users/{id}
    //MARK: GET
    func getHandler(_ req: Request) throws -> Future<User> {
        return try req.parameters.next(User.self)
    }
}

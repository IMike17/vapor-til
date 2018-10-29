import Vapor

struct CategoriesController: RouteCollection {
    func boot(router: Router) throws {
		// MARK: Public
        let categoriesRoutes = router.grouped("api", "categories")
        
        categoriesRoutes.get(use: getAllHandler)
        categoriesRoutes.get(Category.parameter, use: getHandler)
        categoriesRoutes.get(Category.parameter, "acronyms", use: getAcronymsHandler)
		
		// MARK: Secure
		let tokenAuthMiddleware = User.tokenAuthMiddleware()
		let guardAuthMiddleware = User.guardAuthMiddleware()
		
		let tokenAuthGroup = categoriesRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
		tokenAuthGroup.post(Category.self, use: createHandler)
    }
    
    // MARK: - /categories
    // MARK: GET
    func getAllHandler(_ req: Request) -> Future<[Category]> {
        return Category.query(on: req).all()
    }
    
    // MARK: POST
    func createHandler(_ req: Request, category: Category) -> Future<Category> {
        return category.save(on: req)
    }
    
    // MARK: - /categories/{id}
    // MARK: GET
    func getHandler(_ req: Request) throws -> Future<Category> {
        return try req.parameters.next(Category.self)
    }
    
    // MARK: - /categories/{id}/acronyms
    // MARK: GET
    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req.parameters.next(Category.self)
            .flatMap(to: [Acronym].self,
                     { (category) in
                        return try category.acronyms.query(on: req).all()
            })
    }
}

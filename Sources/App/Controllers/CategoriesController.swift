import Vapor

struct CategoriesController: RouteCollection {
    func boot(router: Router) throws {
        let categoriesRoutes = router.grouped("api", "categories")
        
        categoriesRoutes.get(use: getAllHandler)
        categoriesRoutes.post(Category.self, use: createHandler)
        categoriesRoutes.get(Category.parameter, use: getHandler)
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
}

import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    
    let acronymsController = AcronymsController()
    let usersController = UsersController()
    let categoriesController = CategoriesController()
	let webSiteController = WebsiteController()
	let imperialController = ImperialController()
    
    try router.register(collection: acronymsController)
    try router.register(collection: usersController)
    try router.register(collection: categoriesController)
	try router.register(collection: webSiteController)
	try router.register(collection: imperialController)
    
}

import Vapor
import Fluent

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    // Basic "Hello, world!" example
    router.get("hello") { req in
        return "Hello, world!"
    }

    //MARK: - /acronyms
    router.get("api", "acronyms") { (req) -> Future<[Acronym]> in
        return Acronym.query(on: req).all()
    }
    
    router.post("api", "acronyms") { (req) -> Future<Acronym> in
        return try req.content.decode(Acronym.self)
            .flatMap(to: Acronym.self, { (acronym) -> Future<Acronym> in
                return acronym.save(on: req)
            })
    }
    
    //MARK: - /acronyms/{id}
    router.get("api", "acronyms", Acronym.parameter) { (req) -> Future<Acronym> in
        return try req.parameters.next(Acronym.self)
    }
    
    router.put("api", "acronyms", Acronym.parameter) { (req) -> Future<Acronym> in
        return try flatMap(to: Acronym.self, req.parameters.next(Acronym.self), req.content.decode(Acronym.self), { (dbAcronym, requestAcronym) -> Future<Acronym> in
            dbAcronym.short = requestAcronym.short
            dbAcronym.long = requestAcronym.long
            
            return dbAcronym.save(on: req)
        })
    }
    
    router.delete("api", "acronyms", Acronym.parameter) { (req) -> Future<HTTPStatus> in
        return try req.parameters.next(Acronym.self)
            .delete(on: req)
            .transform(to: HTTPStatus.noContent)
    }
    
    //MARK: - /acronyms/first
    /// Searches first acronym in the DB
    router.get("api", "acronyms", "first") { (req) -> Future<Acronym> in
        return Acronym
            .query(on: req)
            .first().map(to: Acronym.self, { (acronym) -> Acronym in
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
    router.get("api", "acronyms", "search") { (req) -> Future<[Acronym]> in
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
    router.get("api", "acronyms", "sorted") { (req) -> Future<[Acronym]> in
        return Acronym
            .query(on: req)
            .sort(\.short, .ascending)
            .all()
    }
}

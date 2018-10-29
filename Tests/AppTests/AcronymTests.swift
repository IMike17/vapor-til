@testable import App
import XCTest
import Vapor
import FluentPostgreSQL

final class AcronymTests: XCTestCase {

    let acronymShort = "OMG"
    let acronymLong = "Oh My God"
    let acronymsURI = "/api/acronyms/"
    var app: Application!
    var conn: PostgreSQLConnection!
    
    //MARK:- Configurations
    override func setUp() {
        try! Application.reset()
        app = try! Application.testable()
        conn = try! app.newConnection(to: .psql).wait()
    }
    
    override func tearDown() {
        conn.close()
		try? app.syncShutdownGracefully()
    }
    
    //MARK:- Tests
    func testAcronymsCanBeRetrievedFromAPI() throws {
        let acronym = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: conn)
        
        _ = try Acronym.create(
            short: "LOL",
            long: "Laugh Out Loud",
            on: conn)
        
        let acronyms = try app.getResponse(
            to: acronymsURI,
            decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
        XCTAssertEqual(acronyms[0].id, acronym.id)
    }
    
    func testAcronymCanBeSavedWithAPI() throws {
        let user = try User.create(on: conn)
        
        let acronym = Acronym(
            short: acronymShort,
            long: acronymLong,
            userID: user.id!)
        
        let receivedAcronym = try app.getResponse(
            to: acronymsURI,
            method: .POST,
            headers: ["Content-Type": "application/json"],
            data: acronym,
            decodeTo: Acronym.self,
			loggedInRequest: true)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertNotNil(receivedAcronym.id)
    }
    
    func testGettingASingleAcronymFromTheAPI() throws {
        let acronym = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: conn)
        
        let receivedAcronym = try app.getResponse(
            to: "\(acronymsURI)\(acronym.id!)",
            decodeTo: Acronym.self)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, acronymLong)
        XCTAssertEqual(receivedAcronym.id, acronym.id)
    }
    
    func testUpdatingAcronym() throws {
        let acronym = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: conn)
        
        let newLong = "Oh My Gosh"
        let newUser = try User.create(on: conn)
        
        let updatedAcronym = Acronym(
            short: acronym.short,
            long: newLong,
            userID: newUser.id!)
        
        try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)",
            method: .PUT,
            headers: ["Content-Type": "application/json"],
            data: updatedAcronym,
			loggedInUser: newUser)
        
        let receivedAcronym = try app.getResponse(
            to: "\(acronymsURI)\(acronym.id!)",
            decodeTo: Acronym.self)
        
        XCTAssertEqual(receivedAcronym.short, acronymShort)
        XCTAssertEqual(receivedAcronym.long, newLong)
        XCTAssertEqual(receivedAcronym.id, acronym.id)
        XCTAssertEqual(receivedAcronym.userID, newUser.id)
    }
    
    func testDeletingAcronym() throws {
        let acronym = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: conn)
        
        var acronyms = try app.getResponse(
            to: acronymsURI,
            decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        
        _ = try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)",
            method: .DELETE,
			loggedInRequest: true)
        
        acronyms = try app.getResponse(
            to: acronymsURI,
            decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 0)
    }
    
    func testGettingAcronymCategories() throws {
        let category1 = try Category.create(on: conn)
        let category2Name = "Funny"
        let category2 = try Category.create(name: category2Name, on: conn)
        
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)/categories/\(category1.id!)",
            method: .POST,
			loggedInRequest: true)
        _ = try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)/categories/\(category2.id!)",
            method: .POST,
			loggedInRequest: true)
        
        let categories = try app.getResponse(
            to: "\(acronymsURI)\(acronym.id!)/categories",
            decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(categories[0].id, category1.id)
        XCTAssertEqual(categories[0].name, category1.name)
        XCTAssertEqual(categories[1].id, category2.id)
        XCTAssertEqual(categories[1].name, category2Name)
    }
    
    func testDeletingAcronymCategory() throws {
        let category = try Category.create(on: conn)
        let acronym = try Acronym.create(on: conn)
        
        _ = try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)",
            method: .POST,
			loggedInRequest: true)
        
        let categories = try app.getResponse(
            to: "\(acronymsURI)\(acronym.id!)/categories",
            decodeTo: [App.Category].self)
        
        XCTAssertEqual(categories.count, 1)
        
        _ = try app.sendRequest(
            to: "\(acronymsURI)\(acronym.id!)/categories/\(category.id!)",
            method: .DELETE,
			loggedInRequest: true)
        
        XCTAssertEqual(categories.count, 1)
    }
    
    func testGettingAcronymUser() throws {
        let user = try User.create(on: conn)
        let acronym = try Acronym.create(
            user: user,
            on: conn)
        
        let acronymUser = try app.getResponse(
            to: "\(acronymsURI)\(acronym.id!)/user",
            decodeTo: User.Public.self)
        
        XCTAssertEqual(acronymUser.id, user.id)
        XCTAssertEqual(acronymUser.name, user.name)
        XCTAssertEqual(acronymUser.username, user.username)
    }
    
    func testGetFirstAcronym() throws {
        let acronym = try Acronym.create(
            short: acronymShort,
            long: acronymLong,
            on: conn)
        _ = try Acronym.create(on: conn)
        _ = try Acronym.create(on: conn)
        
        let firstAcronym = try app.getResponse(
            to: "\(acronymsURI)first",
            decodeTo: Acronym.self)
        
        XCTAssertEqual(firstAcronym.id, acronym.id)
        XCTAssertEqual(firstAcronym.short, acronymShort)
        XCTAssertEqual(firstAcronym.long, acronymLong)
    }
    
    func testSearchAcronymShort() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        print("\(acronymsURI)?term=OMG")
        let acronyms = try app.getResponse(to: "\(acronymsURI)search?term=OMG", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSearchAcronymLong() throws {
        let acronym = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        _ = try Acronym.create(on: conn)
        let acronyms = try app.getResponse(to: "\(acronymsURI)search?term=Oh+My+God", decodeTo: [Acronym].self)
        
        XCTAssertEqual(acronyms.count, 1)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
    }
    
    func testSortingAcronyms() throws {
        let short2 = "LOL"
        let long2 = "Laugh Out Loud"
        let acronym1 = try Acronym.create(short: acronymShort, long: acronymLong, on: conn)
        let acronym2 = try Acronym.create(short: short2, long: long2, on: conn)
        
        let sortedAcronyms = try app.getResponse(to: "\(acronymsURI)sorted", decodeTo: [Acronym].self)
        
        XCTAssertEqual(sortedAcronyms[0].id, acronym2.id)
        XCTAssertEqual(sortedAcronyms[1].id, acronym1.id)
    }
    
    static let allTests = [
        ("testAcronymsCanBeRetrievedFromAPI", testAcronymsCanBeRetrievedFromAPI),
        ("testAcronymCanBeSavedWithAPI", testAcronymCanBeSavedWithAPI),
        ("testGettingASingleAcronymFromTheAPI", testGettingASingleAcronymFromTheAPI),
        ("testUpdatingAcronym", testUpdatingAcronym),
        ("testDeletingAcronym", testDeletingAcronym),
        ("testGettingAcronymCategories", testGettingAcronymCategories),
        ("testDeletingAcronymCategory", testDeletingAcronymCategory),
        ("testGettingAcronymUser", testGettingAcronymUser),
        ("testGetFirstAcronym", testGetFirstAcronym),
        ("testSearchAcronymShort", testSearchAcronymShort),
        ("testSearchAcronymLong", testSearchAcronymLong),
        ("testSortingAcronyms", testSortingAcronyms)
    ]
}

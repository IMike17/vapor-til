import XCTest
@testable import AppTests

XCTMain([
    testCase(UserTests.allTests),
    testCase(CategoryTests.allTests),
    testCase(AcronymTests.allTests)
])

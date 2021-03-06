// swift-tools-version:4.2.0
import PackageDescription

let package = Package(
    name: "TILApp",
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "3.1.0"),

        // 🔵 Swift ORM (queries, models, relations, etc) built on SQLite 3.
        .package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
			
		// 🍃 An expressive, performant, and extensible templating language built for Swift.
		.package(url: "https://github.com/vapor/leaf.git", from: "3.0.1"),
		
		// 👤 Authentication and Authorization framework for Fluent.
		.package(url: "https://github.com/vapor/auth.git", from: "2.0.0-rc"),
		
		// Federated Authentication with OAuth providers
		.package(url: "https://github.com/vapor-community/Imperial.git", from: "0.7.1")
    ],
    targets: [
        .target(name: "App", dependencies: ["FluentPostgreSQL", "Vapor", "Leaf", "Authentication", "Imperial"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
    ]
)


import FluentPostgreSQL
import Vapor
import Leaf
import Authentication

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
	
	/// Configure server to use a custom port
	switch env {
	case Environment.development, Environment.testing:
		services.register { _ in
			NIOServerConfig.default(hostname: "localhost", port: 8008)
		}
	default:
		break
	}
	
    /// Register providers first
    try services.register(FluentPostgreSQLProvider())
	try services.register(LeafProvider())
	try services.register(AuthenticationProvider())

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
	middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
	middlewares.use(SessionsMiddleware.self) // Enables Sessions for requests
    services.register(middlewares)

    // Configure a PostgreSQL database
    var databases = DatabasesConfig()
    
    let hostname = Environment.get("DATABASE_HOSTNAME") ?? "localhost"
    let username = Environment.get("DATABASE_USER") ?? "vapor"
    
    let databaseName: String
    let databasePort: Int
    if (env == .testing) {
        databaseName = "vapor-test"
        if let testPort = Environment.get("DATABASE_PORT") {
            databasePort = Int(testPort) ?? 5433
        } else {
            databasePort = 5433
        }
    } else {
        databaseName = Environment.get("DATABASE_DB") ?? "vapor"
        databasePort = 5432
    }
    
    let password = Environment.get("DATABASE_PASSWORD") ?? "password"
    
    let databaseConfig: PostgreSQLDatabaseConfig
    
    if let url = Environment.get("DATABASE_URL") {
        databaseConfig = PostgreSQLDatabaseConfig(url: url)!
    } else {
        databaseConfig = PostgreSQLDatabaseConfig(
            hostname: hostname,
            port: databasePort,
            username: username,
            database: databaseName,
            password: password)
    }
    
    let database = PostgreSQLDatabase(config: databaseConfig)
    

    /// Register the configured PostgreSQL database to the database config.
    databases.add(database: database, as: .psql)
    services.register(databases)

    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: User.self, database: .psql)
    migrations.add(model: Acronym.self, database: .psql)
    migrations.add(model: Category.self, database: .psql)
    migrations.add(model: AcronymCategoryPivot.self, database: .psql)
	migrations.add(model: Token.self, database: .psql)
	
	switch env {
	case Environment.development, Environment.testing:
		migrations.add(migration: AdminUser.self, database: .psql)
	default:
		break
	}
	
	migrations.add(migration: AddTwitterURLToUser.self, database: .psql)
	migrations.add(migration: MakeCategoriesUnique.self, database: .psql)
    services.register(migrations)
    
    /// Configure commands
    var commandConfig = CommandConfig.default()
    commandConfig.useFluentCommands()
    services.register(commandConfig)

	config.prefer(LeafRenderer.self, for: ViewRenderer.self)
	config.prefer(MemoryKeyedCache.self, for: KeyedCache.self)
}

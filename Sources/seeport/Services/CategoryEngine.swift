import Foundation

enum CategoryEngine {
    private static let frontendCommands: Set<String> = [
        "node", "vite", "next", "react-scripts", "webpack",
        "parcel", "esbuild", "rollup", "nuxt", "angular",
        "vue-cli-service", "gatsby", "svelte"
    ]

    private static let frontendPorts: Set<UInt16> = [
        3000, 3001, 3002, 4200, 5173, 5174, 5175,
        8080, 8081, 4000, 1234
    ]

    private static let backendCommands: Set<String> = [
        "python", "python3", "uvicorn", "gunicorn", "flask",
        "django", "java", "spring", "golang", "cargo", "ruby",
        "rails", "php", "artisan", "dotnet", "beam.smp",
        "erlang", "elixir"
    ]

    private static let backendPorts: Set<UInt16> = [
        8000, 8001, 8443, 9000, 9090, 5000, 5001,
        4567, 3030, 7000, 7001
    ]

    private static let databaseCommands: Set<String> = [
        "postgres", "mysqld", "mongod", "redis-server",
        "memcached", "elasticsearch", "cassandra"
    ]

    private static let databasePorts: Set<UInt16> = [
        5432, 3306, 27017, 6379, 11211, 9200, 9300, 5984
    ]

    private static let systemCommands: Set<String> = [
        "rapportd", "ControlCe", "ControlCenter", "airplaydi", "sharingd",
        "WiFiAgent", "systemsta", "launchd", "mDNSRespo",
        "httpd", "cupsd", "sshd"
    ]

    // Docker image-based classification
    private static let dockerFrontendImages: Set<String> = [
        "nginx", "httpd", "apache", "caddy", "node",
        "next", "nuxt", "react", "vue", "angular"
    ]

    private static let dockerBackendImages: Set<String> = [
        "python", "flask", "django", "uvicorn", "gunicorn",
        "java", "openjdk", "spring", "tomcat", "jetty",
        "golang", "go", "ruby", "rails", "php",
        "laravel", "dotnet", "aspnet", "elixir", "phoenix",
        "rust", "deno", "bun"
    ]

    private static let dockerDatabaseImages: Set<String> = [
        "postgres", "mysql", "mariadb", "mongo", "mongodb",
        "redis", "memcached", "elasticsearch", "opensearch",
        "cassandra", "couchdb", "influxdb", "clickhouse",
        "timescaledb", "cockroachdb", "supabase", "neo4j"
    ]

    static func categorize(port: UInt16, command: String, isDocker: Bool, dockerImage: String? = nil) -> PortCategory {
        if let override = CategoryOverrides.categoryFor(port) { return override }
        if isDocker { return .docker }

        let lowerCommand = command.lowercased()

        if systemCommands.contains(command) || systemCommands.contains(where: { lowerCommand.hasPrefix($0.lowercased()) }) { return .system }
        if databaseCommands.contains(where: { lowerCommand.contains($0) }) { return .backend }
        if databasePorts.contains(port) { return .backend }
        if frontendCommands.contains(where: { lowerCommand.contains($0) }) { return .backend }
        if frontendPorts.contains(port) && lowerCommand.contains("node") { return .backend }
        if backendCommands.contains(where: { lowerCommand.contains($0) }) { return .backend }
        if backendPorts.contains(port) { return .backend }

        return .other
    }

    /// Used for Docker port tags only (Frontend/Backend/Database labels)
    static func portTag(port: UInt16, dockerImage: String?) -> String {
        let img = (dockerImage ?? "").lowercased()

        if dockerDatabaseImages.contains(where: { img.contains($0) }) || databasePorts.contains(port) { return "Database" }
        if dockerFrontendImages.contains(where: { img.contains($0) }) || frontendPorts.contains(port) { return "Frontend" }
        if dockerBackendImages.contains(where: { img.contains($0) }) || backendPorts.contains(port) { return "Backend" }

        return "Service"
    }
}

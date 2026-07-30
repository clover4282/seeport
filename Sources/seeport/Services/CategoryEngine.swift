import Foundation

enum CategoryEngine {
    private static let systemCommands: Set<String> = [
        "rapportd", "ControlCe", "ControlCenter", "airplaydi", "sharingd",
        "WiFiAgent", "systemsta", "launchd", "mDNSRespo",
        "httpd", "cupsd", "sshd"
    ]

    // Docker image-based classification (used for port tags only)
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

    /// Coarse classification: Docker, System, App, or Local. Distinguishing
    /// frontend from backend is unreliable (most dev tooling runs as a bare
    /// `node`/`python` process), so those are folded into `.local`. GUI apps
    /// (Google Drive, Dropbox, …) are split into `.app` so `.local` stays
    /// limited to terminal-launched dev servers.
    static func categorize(port: UInt16, command: String, isDocker: Bool, isApp: Bool = false, dockerImage: String? = nil) -> PortCategory {
        if let override = CategoryOverrides.categoryFor(port) { return override }
        if isDocker { return .docker }

        let lowerCommand = command.lowercased()
        if systemCommands.contains(command) || systemCommands.contains(where: { lowerCommand.hasPrefix($0.lowercased()) }) {
            return .system
        }

        if lowerCommand == "python" || lowerCommand.hasPrefix("python3") { return .local }
        if isApp { return .app }

        return .local
    }

    /// Service-type label for a Docker port mapping, derived from the container
    /// image (reliable, unlike local process-name guessing).
    static func portTag(port: UInt16, dockerImage: String?) -> String {
        let img = (dockerImage ?? "").lowercased()
        guard !img.isEmpty else { return "Service" }

        if dockerDatabaseImages.contains(where: { img.contains($0) }) { return "Database" }
        if dockerFrontendImages.contains(where: { img.contains($0) }) { return "Frontend" }
        if dockerBackendImages.contains(where: { img.contains($0) }) { return "Backend" }

        return "Service"
    }
}

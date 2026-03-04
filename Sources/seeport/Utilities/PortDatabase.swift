import Foundation

enum PortDatabase {
    static func knownServices(for port: UInt16) -> [String] {
        return portMap[port] ?? []
    }

    private static let defaultServers = [
        "Custom Application",
        "Development Server",
        "Internal Service",
        "API Endpoint",
        "Test Server"
    ]

    private static let portMap: [UInt16: [String]] = [
        80:    ["Apache HTTP", "Nginx", "Caddy", "Lighttpd", "IIS"],
        443:   ["Nginx (HTTPS)", "Apache (SSL)", "Caddy", "Node.js HTTPS", "HAProxy"],
        3000:  ["Express.js", "Next.js", "Rails", "Nuxt.js", "Create React App"],
        3001:  ["Express.js (alt)", "Next.js (alt)", "BrowserSync", "React dev", "Remix"],
        4200:  ["Angular CLI", "Angular Dev", "NestJS", "Storybook", "Analog"],
        5000:  ["Flask", "ASP.NET Core", "Vite Preview", "SvelteKit", "Python HTTP"],
        5001:  ["ASP.NET HTTPS", "Flask (alt)", "InfluxDB", "Firebase", "Strapi"],
        5173:  ["Vite", "Vite + React", "Vite + Vue", "Vite + Svelte", "SolidStart"],
        5174:  ["Vite (alt)", "Vite HMR", "Vite + Preact", "Astro", "Qwik"],
        8000:  ["Django", "PHP Built-in", "Uvicorn", "Hugo", "Symfony"],
        8001:  ["Django (alt)", "Webpack DevServer", "Traefik", "Kong Gateway", "gRPC"],
        8080:  ["Tomcat", "Jenkins", "Spring Boot", "WildFly", "Jetty"],
        8081:  ["Nexus", "Nginx (alt)", "JSON Server", "Traefik (alt)", "Webpack"],
        8443:  ["Tomcat HTTPS", "Spring HTTPS", "JIRA", "Atlassian", "WildFly SSL"],
        8888:  ["Jupyter Notebook", "MAMP", "Hashicorp Consul", "Druid", "IPython"],
        9000:  ["PHP-FPM", "SonarQube", "Portainer", "Minio", "ClickHouse"],
        9090:  ["Prometheus", "Cockpit", "Opencast", "Tinyproxy", "Zeus Admin"],
        3306:  ["MySQL", "MariaDB", "Percona", "TiDB", "PlanetScale"],
        5432:  ["PostgreSQL", "CockroachDB", "Supabase", "TimescaleDB", "YugabyteDB"],
        6379:  ["Redis", "KeyDB", "Dragonfly", "Valkey", "Redis Stack"],
        27017: ["MongoDB", "DocumentDB", "FerretDB", "Percona MongoDB", "Atlas"],
        1234:  ["Parcel", "PHP Dev", "Remote Desktop", "Hotspot Shield", "Inferno"],
        3030:  ["Feathers.js", "Grafana Agent", "Mutter", "Airflow", "AREPL"],
        4000:  ["Phoenix (Elixir)", "Gatsby", "Remix Dev", "FastAPI", "Docusaurus"],
        7000:  ["AirPlay", "Cassandra", "Kafka REST", "Spring Cloud", "Hive"],
        7001:  ["WebLogic", "AirPlay (alt)", "Cassandra SSL", "BEA", "Coherence"],
        9200:  ["Elasticsearch", "OpenSearch", "Typesense", "Zinc", "Manticore"],
        11211: ["Memcached", "Couchbase", "AWS ElastiCache", "Twemproxy", "Mcrouter"],
    ]
}

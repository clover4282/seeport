import Foundation
import Network

final class WebServer {
    private var listener: NWListener?
    let port: UInt16
    private let sessionToken: String
    private weak var viewModel: PortListViewModel?

    init(port: UInt16 = 7777, viewModel: PortListViewModel? = nil) {
        self.port = port
        self.viewModel = viewModel
        self.sessionToken = UUID().uuidString
    }

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: .global(qos: .userInitiated))
            print("Seeport server running at http://localhost:\(port)?token=\(sessionToken)")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            Task {
                let response = await self.route(request)
                let responseData = Data(response.utf8)
                connection.send(content: responseData, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
    }

    private func route(_ raw: String) async -> String {
        let lines = raw.split(separator: "\r\n")
        guard let first = lines.first else { return httpResponse(status: 400, body: "Bad Request") }
        let parts = first.split(separator: " ")
        guard parts.count >= 2 else { return httpResponse(status: 400, body: "Bad Request") }
        let method = String(parts[0])
        let fullPath = String(parts[1])

        // Parse path and query parameters
        let components = fullPath.split(separator: "?", maxSplits: 1)
        let path = String(components[0])
        let query = components.count > 1 ? String(components[1]) : ""

        switch (method, path) {
        case ("GET", "/"):
            return httpResponse(contentType: "text/html; charset=utf-8", body: HTMLTemplate.page)
        case ("GET", "/api/ports"):
            return await handleGetPorts()
        case ("POST", _ ) where path.hasPrefix("/api/kill/"):
            guard validateToken(query: query) else {
                return httpResponse(status: 403, body: "Forbidden")
            }
            let pidStr = String(path.dropFirst("/api/kill/".count))
            return await handleKill(pidStr)
        case ("POST", _) where path.hasPrefix("/api/favorite/"):
            guard validateToken(query: query) else {
                return httpResponse(status: 403, body: "Forbidden")
            }
            let portStr = String(path.dropFirst("/api/favorite/".count))
            return handleFavorite(portStr)
        default:
            return httpResponse(status: 404, body: "Not Found")
        }
    }

    private func validateToken(query: String) -> Bool {
        // Accept token from query parameter: ?token=<sessionToken>
        let pairs = query.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2, kv[0] == "token", String(kv[1]) == sessionToken {
                return true
            }
        }
        return false
    }

    private func handleGetPorts() async -> String {
        // Use shared ViewModel data if available, else scan independently
        if let vm = viewModel {
            let ports = await MainActor.run { vm.ports }
            let json = portsToJSON(ports)
            return httpResponse(contentType: "application/json", body: json)
        }

        // Fallback: independent scan
        let portScanner = PortScanner()
        let dockerService = DockerService()
        var ports = await portScanner.scan()
        let containers = await dockerService.fetchContainersIfAvailable()

        ports = ports.map { port in
            let container = containers.first { c in c.ports.contains { $0.hostPort == port.port } }
            let isDocker = container != nil
            let isApp = isDocker ? false : ProcessService.isApplication(pid: port.process.pid)
            let category = CategoryEngine.categorize(port: port.port, command: port.process.name, isDocker: isDocker, isApp: isApp, dockerImage: container?.image)
            return PortInfo(
                port: port.port,
                process: port.process,
                category: category,
                address: port.address,
                isFavorite: Favorites.isFavorite(port.port),
                dockerContainer: container
            )
        }

        let json = portsToJSON(ports)
        return httpResponse(contentType: "application/json", body: json)
    }

    private func handleKill(_ pidStr: String) async -> String {
        guard let pid = Int32(pidStr) else {
            return httpResponse(status: 400, contentType: "application/json", body: "{\"error\":\"invalid pid\"}")
        }
        // Only allow killing PIDs from the current scan
        if let vm = viewModel {
            let knownPids = await MainActor.run { Set(vm.ports.map(\.process.pid)) }
            guard knownPids.contains(pid) else {
                return httpResponse(status: 403, contentType: "application/json", body: "{\"error\":\"pid not in scan\"}")
            }
        }
        let ok = await ProcessService.kill(pid: pid)
        return httpResponse(contentType: "application/json", body: "{\"success\":\(ok)}")
    }

    private func handleFavorite(_ portStr: String) -> String {
        guard let port = UInt16(portStr) else {
            return httpResponse(status: 400, contentType: "application/json", body: "{\"error\":\"invalid port\"}")
        }
        let isFav = Favorites.toggle(port)
        return httpResponse(contentType: "application/json", body: "{\"isFavorite\":\(isFav)}")
    }

    private func httpResponse(status: Int = 200, contentType: String = "text/plain", body: String) -> String {
        let statusText: String
        switch status {
        case 200: statusText = "OK"
        case 400: statusText = "Bad Request"
        case 403: statusText = "Forbidden"
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }
        return """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: http://localhost:\(port)\r
        Connection: close\r
        \r
        \(body)
        """
    }

    private func portsToJSON(_ ports: [PortInfo]) -> String {
        let items = ports.map { p in
            var docker = "null"
            if let c = p.dockerContainer {
                docker = "{\"id\":\"\(escapeJSON(c.id))\",\"name\":\"\(escapeJSON(c.name))\",\"image\":\"\(escapeJSON(c.image))\"}"
            }
            let browserURL = escapeJSON(BrowserLauncher.urlString(address: p.address, port: p.port) ?? "")
            return """
            {"port":\(p.port),"address":"\(p.address)","browserURL":"\(browserURL)","process":{"pid":\(p.process.pid),"name":"\(escapeJSON(p.process.name))","user":"\(escapeJSON(p.process.user))"},"category":"\(p.category.rawValue)","isFavorite":\(p.isFavorite),"docker":\(docker)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
         .replacingOccurrences(of: "\n", with: "\\n")
         .replacingOccurrences(of: "\r", with: "\\r")
         .replacingOccurrences(of: "\t", with: "\\t")
    }
}

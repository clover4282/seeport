import Foundation
import Network

final class WebServer {
    private var listener: NWListener?
    let port: UInt16
    private let portScanner = PortScanner()
    private let dockerService = DockerService()

    init(port: UInt16 = 7777) {
        self.port = port
    }

    func start() {
        do {
            let params = NWParameters.tcp
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            listener?.start(queue: .global(qos: .userInitiated))
            print("seeport server running at http://localhost:\(port)")
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
            guard let self = self, let data = data, let request = String(data: data, encoding: .utf8) else {
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
        let path = String(parts[1])

        switch (method, path) {
        case ("GET", "/"):
            return httpResponse(contentType: "text/html; charset=utf-8", body: HTMLTemplate.page)
        case ("GET", "/api/ports"):
            return await handleGetPorts()
        case ("POST", _ ) where path.hasPrefix("/api/kill/"):
            let pidStr = String(path.dropFirst("/api/kill/".count))
            return await handleKill(pidStr)
        case ("POST", _) where path.hasPrefix("/api/favorite/"):
            let portStr = String(path.dropFirst("/api/favorite/".count))
            return handleFavorite(portStr)
        default:
            return httpResponse(status: 404, body: "Not Found")
        }
    }

    private func handleGetPorts() async -> String {
        var ports = await portScanner.scan()
        await dockerService.checkAvailability()
        let containers = await dockerService.fetchContainers()

        ports = ports.map { port in
            let container = containers.first { c in c.ports.contains { $0.hostPort == port.port } }
            let isDocker = container != nil
            let category = CategoryEngine.categorize(port: port.port, command: port.process.name, isDocker: isDocker, dockerImage: container?.image)
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
        case 404: statusText = "Not Found"
        default: statusText = "Error"
        }
        return """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.utf8.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r
        \(body)
        """
    }

    private func portsToJSON(_ ports: [PortInfo]) -> String {
        let items = ports.map { p in
            var docker = "null"
            if let c = p.dockerContainer {
                docker = "{\"id\":\"\(c.id)\",\"name\":\"\(c.name)\",\"image\":\"\(c.image)\"}"
            }
            return """
            {"port":\(p.port),"address":"\(p.address)","process":{"pid":\(p.process.pid),"name":"\(escapeJSON(p.process.name))","user":"\(escapeJSON(p.process.user))"},"category":"\(p.category.rawValue)","isFavorite":\(p.isFavorite),"docker":\(docker)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    private func escapeJSON(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

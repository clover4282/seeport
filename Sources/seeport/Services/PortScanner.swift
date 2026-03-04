import Foundation

actor PortScanner {
    func scan() async -> [PortInfo] {
        let result = await ShellExecutor.runAsync("lsof -iTCP -sTCP:LISTEN -nP -F pcnf 2>/dev/null")
        guard result.exitCode == 0 || !result.output.isEmpty else { return [] }
        return parse(result.output)
    }

    private func parse(_ output: String) -> [PortInfo] {
        var ports: [PortInfo] = []
        var currentPID: Int32 = 0
        var currentCommand = ""
        let currentUser = NSUserName()

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let str = String(line)
            guard !str.isEmpty else { continue }

            let prefix = str.first!
            let value = String(str.dropFirst())

            switch prefix {
            case "p":
                currentPID = Int32(value) ?? 0
            case "c":
                currentCommand = value
            case "n":
                if let port = extractPort(from: value) {
                    let address = extractAddress(from: value)
                    let processInfo = ProcessInfo(
                        id: currentPID,
                        name: currentCommand,
                        user: currentUser
                    )
                    let portInfo = PortInfo(
                        port: port,
                        process: processInfo,
                        address: address,
                        isFavorite: Favorites.isFavorite(port)
                    )
                    if !ports.contains(where: { $0.port == port && $0.process.pid == currentPID }) {
                        ports.append(portInfo)
                    }
                }
            default:
                break
            }
        }

        return ports
    }

    private func extractPort(from name: String) -> UInt16? {
        let parts = name.split(separator: ":")
        guard let last = parts.last, let port = UInt16(last) else { return nil }
        return port
    }

    private func extractAddress(from name: String) -> String {
        let parts = name.split(separator: ":")
        if parts.count >= 2 {
            let addr = String(parts[0..<parts.count-1].joined(separator: ":"))
            if addr == "*" { return "0.0.0.0" }
            return addr
        }
        return "127.0.0.1"
    }
}

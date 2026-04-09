import Foundation

actor DockerService {
    private(set) var isAvailable = false
    private var dockerPath = "docker"
    private var lastAvailabilityCheck: Date?
    private let availabilityCacheSeconds: TimeInterval = 30

    private static let dockerSearchPaths = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        "/usr/bin/docker",
        "/Applications/Docker.app/Contents/Resources/bin/docker",
        "/Applications/OrbStack.app/Contents/MacOS/xbin/docker",
    ]

    /// Fetch containers, checking availability only if cache expired.
    func fetchContainersIfAvailable() async -> [DockerContainer] {
        let now = Date()
        if let last = lastAvailabilityCheck, now.timeIntervalSince(last) < availabilityCacheSeconds {
            // Use cached availability
        } else {
            await checkAvailability()
            lastAvailabilityCheck = now
        }
        return await fetchContainers()
    }

    func checkAvailability() async {
        // GUI apps launched via launchd have a minimal PATH that excludes
        // /usr/local/bin, /opt/homebrew/bin, etc. Search known paths directly.
        let fm = FileManager.default
        if let found = Self.dockerSearchPaths.first(where: { fm.isExecutableFile(atPath: $0) }) {
            dockerPath = found
            isAvailable = true
            return
        }
        isAvailable = false
    }

    private func isValidContainerId(_ id: String) -> Bool {
        !id.isEmpty && id.allSatisfy { $0.isHexDigit }
    }

    func fetchContainers() async -> [DockerContainer] {
        guard isAvailable else { return [] }

        let result = await ShellExecutor.runDirectAsync(
            dockerPath, arguments: ["ps", "--format", "{{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Image}}\t{{.Status}}"]
        )
        guard result.exitCode == 0 else { return [] }
        return parse(result.output)
    }

    private func parse(_ output: String) -> [DockerContainer] {
        var containers: [DockerContainer] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = String(line).split(separator: "\t", maxSplits: 4).map(String.init)
            guard parts.count >= 5 else { continue }

            let id = parts[0]
            let name = parts[1]
            let portsStr = parts[2]
            let image = parts[3]
            let status = parts[4]

            let portMappings = parsePortMappings(portsStr)

            let taggedMappings = portMappings.map { m in
                var tagged = m
                tagged.tag = CategoryEngine.portTag(port: m.hostPort, dockerImage: image)
                return tagged
            }

            containers.append(DockerContainer(
                id: id,
                name: name,
                image: image,
                status: status,
                ports: taggedMappings,
                projectPath: nil
            ))
        }

        return containers
    }

    private func parsePortMappings(_ portsStr: String) -> [DockerContainer.PortMapping] {
        var mappings: [DockerContainer.PortMapping] = []

        // Format: 0.0.0.0:8080->80/tcp, :::8080->80/tcp
        // Range:  0.0.0.0:18000-18001->18000-18001/tcp
        let segments = portsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for segment in segments {
            guard segment.contains("->") else { continue }

            let arrowParts = segment.components(separatedBy: "->")
            guard arrowParts.count == 2 else { continue }

            let hostPart = arrowParts[0]
            let containerPart = arrowParts[1]

            // Extract protocol
            let containerComponents = containerPart.split(separator: "/")
            let proto = containerComponents.count > 1 ? String(containerComponents[1]) : "tcp"
            let containerPortStr = String(containerComponents.first ?? "")

            let hostBindings = parseHostBinding(hostPart)
            let containerPorts = parsePortOrRange(containerPortStr)

            guard !hostBindings.isEmpty, !containerPorts.isEmpty else { continue }

            // Pair host ports with container ports
            for (idx, (hostAddress, hostPort)) in hostBindings.enumerated() {
                let containerPort = idx < containerPorts.count ? containerPorts[idx] : containerPorts.last!
                mappings.append(DockerContainer.PortMapping(
                    hostAddress: hostAddress,
                    hostPort: hostPort,
                    containerPort: containerPort,
                    proto: proto
                ))
            }
        }

        // Deduplicate (IPv4 + IPv6 both show up)
        var seen = Set<String>()
        return mappings.filter { m in
            let key = "\(m.hostPort)-\(m.containerPort)-\(m.proto)"
            return seen.insert(key).inserted
        }
    }

    private func parseHostBinding(_ hostPart: String) -> [(address: String, port: UInt16)] {
        let trimmed = hostPart.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let separator = trimmed.lastIndex(of: ":") {
            let portStart = trimmed.index(after: separator)
            guard portStart < trimmed.endIndex else { return [] }

            var address = String(trimmed[..<separator])
            if address.hasPrefix("[") && address.hasSuffix("]") {
                address.removeFirst()
                address.removeLast()
            }
            if address.isEmpty {
                address = "::"
            }

            let ports = parsePortOrRange(String(trimmed[portStart...]))
            return ports.map { (address, $0) }
        }

        let ports = parsePortOrRange(trimmed)
        return ports.map { ("0.0.0.0", $0) }
    }

    private func parsePortOrRange(_ str: String) -> [UInt16] {
        if let port = UInt16(str) {
            return [port]
        }
        // Handle range: "18000-18001"
        let parts = str.split(separator: "-", maxSplits: 1)
        guard parts.count == 2,
              let start = UInt16(parts[0]),
              let end = UInt16(parts[1]),
              start <= end,
              end - start < 100 // safety limit
        else { return [] }
        return Array(start...end)
    }

    func enrichWithProjectPaths(_ containers: [DockerContainer]) async -> [DockerContainer] {
        guard !containers.isEmpty else { return containers }

        // Batch: single docker inspect call for all containers
        let validIds = containers.map(\.id).filter { isValidContainerId($0) }
        guard !validIds.isEmpty else { return containers }
        var args = ["inspect", "--format", "{{.Id}}\t{{range .Mounts}}{{if eq .Type \"bind\"}}{{.Source}}{{\"\n\"}}{{end}}{{end}}"]
        args.append(contentsOf: validIds)
        let result = await ShellExecutor.runDirectAsync(dockerPath, arguments: args)

        // Parse batch output: each container's output starts with full ID + tab
        var pathMap: [String: String] = [:]
        if result.exitCode == 0 {
            // docker inspect outputs one block per container; Id line starts each block
            var currentShortId: String?
            for line in result.output.split(separator: "\n", omittingEmptySubsequences: true) {
                let s = String(line)
                if s.contains("\t") {
                    let parts = s.split(separator: "\t", maxSplits: 1)
                    let fullId = String(parts[0])
                    // Match by short ID prefix (docker ps uses short IDs)
                    let shortId = containers.first { fullId.hasPrefix($0.id) }?.id
                    currentShortId = shortId
                    // If there's a path after the tab, use it
                    if parts.count > 1 {
                        let path = String(parts[1])
                        if !path.isEmpty && path != "/", let sid = currentShortId, pathMap[sid] == nil {
                            pathMap[sid] = path
                        }
                    }
                } else if let sid = currentShortId, pathMap[sid] == nil {
                    // Continuation line: a bind mount path
                    let path = s.trimmingCharacters(in: .whitespaces)
                    if !path.isEmpty && path != "/" {
                        pathMap[sid] = path
                    }
                }
            }
        }

        return containers.map { container in
            var c = container
            if let path = pathMap[container.id] {
                c.projectPath = path
            }
            return c
        }
    }

    func stop(id: String) async -> Bool {
        guard isValidContainerId(id) else { return false }
        let result = await ShellExecutor.runDirectAsync(dockerPath, arguments: ["stop", id])
        return result.exitCode == 0
    }

    func start(id: String) async -> Bool {
        guard isValidContainerId(id) else { return false }
        let result = await ShellExecutor.runDirectAsync(dockerPath, arguments: ["start", id])
        return result.exitCode == 0
    }

    func restart(id: String) async -> Bool {
        guard isValidContainerId(id) else { return false }
        let result = await ShellExecutor.runDirectAsync(dockerPath, arguments: ["restart", id])
        return result.exitCode == 0
    }

    func containerForPort(_ port: UInt16, containers: [DockerContainer]) -> DockerContainer? {
        containers.first { container in
            container.ports.contains { $0.hostPort == port }
        }
    }
}

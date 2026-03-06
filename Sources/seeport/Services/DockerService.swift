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
        // Fallback: try PATH lookup (works when launched from terminal)
        let result = await ShellExecutor.runAsync("which docker 2>/dev/null")
        if result.exitCode == 0 {
            let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !path.isEmpty {
                dockerPath = path
                isAvailable = true
                return
            }
        }
        isAvailable = false
    }

    func fetchContainers() async -> [DockerContainer] {
        guard isAvailable else { return [] }

        let result = await ShellExecutor.runAsync(
            "\(dockerPath) ps --format '{{.ID}}\\t{{.Names}}\\t{{.Ports}}\\t{{.Image}}\\t{{.Status}}' 2>/dev/null"
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
        let segments = portsStr.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for segment in segments {
            guard segment.contains("->") else { continue }

            let arrowParts = segment.split(separator: "-", maxSplits: 1)
            guard arrowParts.count == 2 else { continue }

            let hostPart = String(arrowParts[0])
            let containerPart = String(arrowParts[1]).replacingOccurrences(of: ">", with: "")

            // Extract host port (last component after :)
            guard let hostPort = hostPart.split(separator: ":").last.flatMap({ UInt16($0) }) else { continue }

            // Extract container port and protocol
            let containerComponents = containerPart.split(separator: "/")
            guard let containerPort = containerComponents.first.flatMap({ UInt16($0) }) else { continue }
            let proto = containerComponents.count > 1 ? String(containerComponents[1]) : "tcp"

            mappings.append(DockerContainer.PortMapping(
                hostPort: hostPort,
                containerPort: containerPort,
                proto: proto
            ))
        }

        // Deduplicate (IPv4 + IPv6 both show up)
        var seen = Set<String>()
        return mappings.filter { m in
            let key = "\(m.hostPort)-\(m.containerPort)-\(m.proto)"
            return seen.insert(key).inserted
        }
    }

    func enrichWithProjectPaths(_ containers: [DockerContainer]) async -> [DockerContainer] {
        guard !containers.isEmpty else { return containers }

        // Batch: single docker inspect call for all containers
        let ids = containers.map(\.id).joined(separator: " ")
        let result = await ShellExecutor.runAsync(
            "\(dockerPath) inspect --format '{{.Id}}\\t{{range .Mounts}}{{if eq .Type \"bind\"}}{{.Source}}{{\"\\n\"}}{{end}}{{end}}' \(ids) 2>/dev/null"
        )

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
        let result = await ShellExecutor.runAsync("\(dockerPath) stop \(id) 2>/dev/null")
        return result.exitCode == 0
    }

    func start(id: String) async -> Bool {
        let result = await ShellExecutor.runAsync("\(dockerPath) start \(id) 2>/dev/null")
        return result.exitCode == 0
    }

    func restart(id: String) async -> Bool {
        let result = await ShellExecutor.runAsync("\(dockerPath) restart \(id) 2>/dev/null")
        return result.exitCode == 0
    }

    func containerForPort(_ port: UInt16, containers: [DockerContainer]) -> DockerContainer? {
        containers.first { container in
            container.ports.contains { $0.hostPort == port }
        }
    }
}

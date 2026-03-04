import Foundation

actor DockerService {
    private(set) var isAvailable = false

    func checkAvailability() async {
        let result = await ShellExecutor.runAsync("which docker 2>/dev/null")
        isAvailable = result.exitCode == 0 && !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func fetchContainers() async -> [DockerContainer] {
        guard isAvailable else { return [] }

        let result = await ShellExecutor.runAsync(
            "docker ps --format '{{.ID}}\\t{{.Names}}\\t{{.Ports}}\\t{{.Image}}\\t{{.Status}}' 2>/dev/null"
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
                ports: taggedMappings
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

    func containerForPort(_ port: UInt16, containers: [DockerContainer]) -> DockerContainer? {
        containers.first { container in
            container.ports.contains { $0.hostPort == port }
        }
    }
}

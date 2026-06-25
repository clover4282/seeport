import Foundation

struct DockerContainer: Identifiable, Hashable {
    let id: String
    let name: String
    let image: String
    let status: String
    let ports: [PortMapping]
    var projectPath: String?

    struct PortMapping: Hashable {
        let hostAddress: String
        let hostPort: UInt16
        let containerPort: UInt16
        let proto: String

        // Tag is set externally based on container image
        var tag: String = "Service"
    }
}

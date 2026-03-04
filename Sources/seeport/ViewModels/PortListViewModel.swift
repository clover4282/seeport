import SwiftUI
import Combine
import AppKit
import UserNotifications

enum FilterTab: String, CaseIterable {
    case all = "All"
    case docker = "Docker"
    case favorites = "Favorites"
}

@MainActor
final class PortListViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var searchText = ""
    @Published var selectedTab: FilterTab = .all
    @Published var isScanning = false
    @Published var lastScanTime: Date?
    @Published var portCount: Int = 0
    @Published var dockerContainers: [DockerContainer] = []
    @Published var processIcons: [Int32: NSImage] = [:]

    private let settings = SettingsManager.shared
    private let portScanner = PortScanner()
    private let dockerService = DockerService()
    private var timer: Timer?
    private var knownPorts: Set<UInt16> = []
    private var isFirstScan = true

    var autoRefreshEnabled: Bool { settings.autoRefreshEnabled }
    var autoRefreshInterval: TimeInterval { settings.refreshInterval }

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        applySettings()
    }

    func applySettings() {
        if settings.autoRefreshEnabled {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }

    var filteredPorts: [PortInfo] {
        var result = ports

        // Tab filter
        switch selectedTab {
        case .all, .docker:
            break
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                String($0.port).contains(query) ||
                $0.process.name.lowercased().contains(query) ||
                $0.category.rawValue.lowercased().contains(query) ||
                ($0.dockerContainer?.name.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    var groupedPorts: [(PortCategory, [PortInfo])] {
        let grouped = Dictionary(grouping: filteredPorts, by: \.category)
        let order: [PortCategory] = [.backend, .docker, .system, .other]
        return order.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.port < $1.port })
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true

        async let scannedPorts = portScanner.scan()
        await dockerService.checkAvailability()
        async let containers = dockerService.fetchContainers()

        var results = await scannedPorts
        let dockerContainers_ = await containers

        // Enrich with Docker info and categories
        results = results.map { port in
            var updated = port
            let container = dockerContainers_.first { c in
                c.ports.contains { $0.hostPort == port.port }
            }
            updated.dockerContainer = container
            let isDocker = container != nil
            let category = CategoryEngine.categorize(
                port: port.port,
                command: port.process.name,
                isDocker: isDocker,
                dockerImage: container?.image
            )
            updated = PortInfo(
                port: updated.port,
                process: updated.process,
                category: category,
                address: updated.address,
                isFavorite: Favorites.isFavorite(updated.port),
                dockerContainer: updated.dockerContainer
            )
            return updated
        }

        ports = results.sorted { $0.port < $1.port }
        dockerContainers = dockerContainers_
        portCount = ports.count
        lastScanTime = Date()

        // Cache process icons
        if settings.showProcessIcons {
            for port in ports {
                let pid = port.process.pid
                if processIcons[pid] == nil {
                    processIcons[pid] = ProcessService.icon(for: pid)
                }
            }
        }
        // Remove stale icons
        let activePids = Set(ports.map(\.process.pid))
        processIcons = processIcons.filter { activePids.contains($0.key) }

        // Detect new ports
        let currentPorts = Set(ports.map(\.port))
        if !isFirstScan {
            let newPorts = currentPorts.subtracting(knownPorts)
            for newPort in newPorts {
                if let info = ports.first(where: { $0.port == newPort }) {
                    sendNotification(for: info)
                }
            }
        }
        knownPorts = currentPorts
        isFirstScan = false
        isScanning = false
    }

    func toggleFavorite(_ port: PortInfo) {
        let newState = Favorites.toggle(port.port)
        if let index = ports.firstIndex(where: { $0.port == port.port && $0.process.pid == port.process.pid }) {
            ports[index].isFavorite = newState
        }
    }

    private func sendNotification(for port: PortInfo) {
        let name = port.dockerContainer?.name ?? port.process.name
        let content = UNMutableNotificationContent()
        content.title = "New port detected"
        content.body = "Port \(port.port) — \(name)"
        content.sound = .default

        // Attach process icon
        if let icon = processIcons[port.process.pid] ?? ProcessService.iconOrNil(for: port.process.pid),
           let attachment = saveIconAttachment(icon: icon, pid: port.process.pid) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "seeport.newport.\(port.port)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func saveIconAttachment(icon: NSImage, pid: Int32) -> UNNotificationAttachment? {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("seeport_icon_\(pid).png")
        guard let tiff = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        do {
            try png.write(to: tmpURL)
            return try UNNotificationAttachment(
                identifier: "icon_\(pid)",
                url: tmpURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
            )
        } catch {
            return nil
        }
    }

    func moveToOther(_ port: PortInfo) {
        CategoryOverrides.setOther(port.port)
        if let index = ports.firstIndex(where: { $0.port == port.port && $0.process.pid == port.process.pid }) {
            ports[index] = PortInfo(
                port: port.port,
                process: port.process,
                category: .other,
                address: port.address,
                isFavorite: port.isFavorite,
                dockerContainer: port.dockerContainer
            )
        }
    }

    func restoreCategory(_ port: PortInfo) {
        CategoryOverrides.remove(port.port)
        let isDocker = port.dockerContainer != nil
        let originalCategory = CategoryEngine.categorize(
            port: port.port,
            command: port.process.name,
            isDocker: isDocker,
            dockerImage: port.dockerContainer?.image
        )
        if let index = ports.firstIndex(where: { $0.port == port.port && $0.process.pid == port.process.pid }) {
            ports[index] = PortInfo(
                port: port.port,
                process: port.process,
                category: originalCategory,
                address: port.address,
                isFavorite: port.isFavorite,
                dockerContainer: port.dockerContainer
            )
        }
    }

    func hasOverride(_ port: PortInfo) -> Bool {
        CategoryOverrides.categoryFor(port.port) != nil
    }

    func killProcess(_ port: PortInfo) async {
        let success = await ProcessService.kill(pid: port.process.pid)
        if success {
            // Brief delay then refresh
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func tabCount(for tab: FilterTab) -> Int {
        switch tab {
        case .all: return ports.count
        case .docker: return dockerContainers.count
        case .favorites: return ports.filter { $0.isFavorite }.count
        }
    }
}

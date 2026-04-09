import SwiftUI
import Combine
import AppKit
import UserNotifications

enum FilterTab: String, CaseIterable {
    case all = "All"
    case local = "Local"
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
    private var lastKnownPortInfo: [UInt16: PortInfo] = [:]
    private var isFirstScan = true
    private var workingDirCache: [Int32: String?] = [:]
    private(set) var isPopoverVisible = false

    var autoRefreshEnabled: Bool { settings.autoRefreshEnabled }
    var autoRefreshInterval: TimeInterval { settings.refreshInterval }

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        applySettings()
    }

    func applySettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] s in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.settings.autoRefreshEnabled && s.authorizationStatus == .authorized {
                    self.startAutoRefresh()
                } else {
                    self.stopAutoRefresh()
                }
            }
        }
    }

    // MARK: - Filtering

    var filteredPorts: [PortInfo] {
        var result = ports

        // Tab filter
        switch selectedTab {
        case .all, .docker:
            break
        case .local:
            result = result.filter { $0.category != .system && $0.category != .other && $0.dockerContainer == nil }
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

    var filteredDockerContainers: [DockerContainer] {
        guard !searchText.isEmpty else { return dockerContainers }
        let query = searchText.lowercased()
        return dockerContainers.filter { c in
            c.name.lowercased().contains(query) ||
            c.image.lowercased().contains(query) ||
            c.id.lowercased().contains(query) ||
            c.ports.contains { String($0.hostPort).contains(query) }
        }
    }

    var groupedPorts: [(PortCategory, [PortInfo])] {
        let favoritePorts = filteredPorts.filter { $0.isFavorite }
        let nonFavoritePorts = filteredPorts.filter { !$0.isFavorite }

        var result: [(PortCategory, [PortInfo])] = []

        if !favoritePorts.isEmpty {
            result.append((.favorites, favoritePorts.sorted { $0.port < $1.port }))
        }

        let grouped = Dictionary(grouping: nonFavoritePorts, by: \.category)
        let order: [PortCategory] = [.frontend, .backend, .database, .docker, .system, .other]
        result += order.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.port < $1.port })
        }

        return result
    }

    // MARK: - Popover & Timer

    func setPopoverVisible(_ visible: Bool) {
        isPopoverVisible = visible
        if visible {
            Task { await refresh() }
            restartTimer()
        } else {
            restartTimer()
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        let refreshFunc: () async -> Void = isPopoverVisible ? refresh : lightRefresh
        Task { await refreshFunc() }
        restartTimer()
    }

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isPopoverVisible {
                    await self.refresh()
                } else {
                    await self.lightRefresh()
                }
            }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Scanning

    /// Lightweight refresh: port scan only (no Docker, no working dir, no icons).
    func lightRefresh() async {
        let scannedPorts = await portScanner.scan()

        let results = scannedPorts.map { port -> PortInfo in
            let category = CategoryEngine.categorize(
                port: port.port,
                command: port.process.name,
                isDocker: false,
                dockerImage: nil
            )
            return PortInfo(
                port: port.port,
                process: port.process,
                category: category,
                address: port.address,
                isFavorite: Favorites.isFavorite(port.port)
            )
        }

        let currentPorts = Set(results.map(\.port))
        processPortNotifications(currentPorts: currentPorts, results: results)

        ports = results.sorted { $0.port < $1.port }
        portCount = ports.count
        lastScanTime = Date()
    }

    func refresh() async {
        guard !isScanning else { return }
        isScanning = true

        async let scannedPorts = portScanner.scan()
        async let containers = dockerService.fetchContainersIfAvailable()

        var results = await scannedPorts
        var dockerContainers_ = await containers

        // Enrich Docker containers with project paths
        dockerContainers_ = await dockerService.enrichWithProjectPaths(dockerContainers_)

        // Enrich with Docker info and categories
        results = enrichWithDocker(results, containers: dockerContainers_)

        // Enrich local (non-Docker) ports with working directory (parallel)
        results = await enrichWithWorkingDirectories(results)

        // Propagate Docker project path to port
        for i in results.indices {
            if let containerPath = results[i].dockerContainer?.projectPath {
                results[i].projectPath = containerPath
            }
        }

        ports = results.sorted { $0.port < $1.port }
        dockerContainers = dockerContainers_
        portCount = ports.count
        lastScanTime = Date()

        // Load process icons off the main thread
        if settings.showProcessIcons {
            await updateIconCache(for: ports)
        }
        let activePidsSet = Set(ports.map(\.process.pid))
        processIcons = processIcons.filter { activePidsSet.contains($0.key) }

        // Detect new and removed ports
        let currentPorts = Set(ports.map(\.port))
        processPortNotifications(currentPorts: currentPorts, results: ports)

        isScanning = false
    }

    // MARK: - Enrichment Helpers

    private func enrichWithDocker(_ ports: [PortInfo], containers: [DockerContainer]) -> [PortInfo] {
        ports.map { port in
            let container = containers.first { c in
                c.ports.contains { $0.hostPort == port.port }
            }
            let isDocker = container != nil
            let category = CategoryEngine.categorize(
                port: port.port,
                command: port.process.name,
                isDocker: isDocker,
                dockerImage: container?.image
            )
            return PortInfo(
                port: port.port,
                process: port.process,
                category: category,
                address: port.address,
                isFavorite: Favorites.isFavorite(port.port),
                dockerContainer: container
            )
        }
    }

    private func enrichWithWorkingDirectories(_ results: [PortInfo]) async -> [PortInfo] {
        var updated = results
        let activePidsSet = Set(results.map(\.process.pid))
        workingDirCache = workingDirCache.filter { activePidsSet.contains($0.key) }

        // Collect uncached PIDs
        var uncachedIndices: [Int] = []
        for i in updated.indices where updated[i].dockerContainer == nil && updated[i].category != .system {
            let pid = updated[i].process.pid
            if let cached = workingDirCache[pid] {
                updated[i].projectPath = cached
            } else {
                uncachedIndices.append(i)
            }
        }

        // Fetch uncached working directories in parallel
        if !uncachedIndices.isEmpty {
            let pidsToFetch = uncachedIndices.map { updated[$0].process.pid }
            let paths = await withTaskGroup(of: (Int32, String?).self, returning: [(Int32, String?)].self) { group in
                for pid in pidsToFetch {
                    group.addTask {
                        let path = await ProcessService.getWorkingDirectory(pid: pid)
                        return (pid, path)
                    }
                }
                var collected: [(Int32, String?)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            for (pid, path) in paths {
                workingDirCache[pid] = path
            }
            for i in uncachedIndices {
                let pid = updated[i].process.pid
                updated[i].projectPath = workingDirCache[pid] ?? nil
            }
        }

        return updated
    }

    private func updateIconCache(for ports: [PortInfo]) async {
        let newPids = ports.map(\.process.pid).filter { processIcons[$0] == nil }
        guard !newPids.isEmpty else { return }

        let icons = await withTaskGroup(of: (Int32, NSImage?).self, returning: [(Int32, NSImage?)].self) { group in
            for pid in newPids {
                group.addTask {
                    let icon = await ProcessService.loadIconAsync(for: pid)
                    return (pid, icon)
                }
            }
            var collected: [(Int32, NSImage?)] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        for (pid, icon) in icons {
            if let icon {
                processIcons[pid] = icon
            }
        }
    }

    // MARK: - Notifications

    private func processPortNotifications(currentPorts: Set<UInt16>, results: [PortInfo]) {
        if !isFirstScan {
            if settings.notifyNewPort {
                let newPorts = currentPorts.subtracting(knownPorts)
                for newPort in newPorts {
                    if let info = results.first(where: { $0.port == newPort }),
                       shouldNotify(for: info.category) {
                        sendNotification(for: info)
                    }
                }
            }
            if settings.notifyRemovedPort {
                let removedPorts = knownPorts.subtracting(currentPorts)
                for removedPort in removedPorts {
                    let category = lastKnownPortInfo[removedPort]?.category
                    if let category, shouldNotify(for: category) {
                        sendRemovedNotification(port: removedPort)
                    }
                }
            }
        }
        // Update tracking state
        for info in results {
            lastKnownPortInfo[info.port] = info
        }
        knownPorts = currentPorts
        isFirstScan = false
    }

    private func shouldNotify(for category: PortCategory) -> Bool {
        switch category {
        case .frontend, .backend: return settings.notifyLocalPorts
        case .docker: return settings.notifyDockerPorts
        case .system: return settings.notifySystemPorts
        case .other: return settings.notifyOtherPorts
        case .database: return settings.notifyLocalPorts
        case .favorites: return false
        }
    }

    private func sendNotification(for port: PortInfo) {
        let name = port.dockerContainer?.name ?? port.process.name
        let tag = CategoryEngine.portTag(port: port.port, dockerImage: port.dockerContainer?.image)
        let content = UNMutableNotificationContent()
        content.title = "\(name) · :\(port.port)"
        content.body = "localhost:\(port.port) is now listening (\(tag))"
        content.sound = .default

        // Attach process icon (async-safe: write in background)
        if let icon = processIcons[port.process.pid] ?? ProcessService.iconOrNil(for: port.process.pid) {
            if let attachment = saveIconAttachment(icon: icon, pid: port.process.pid) {
                content.attachments = [attachment]
            }
        }

        let request = UNNotificationRequest(
            identifier: "seeport.newport.\(port.port)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendRemovedNotification(port: UInt16) {
        let content = UNMutableNotificationContent()
        if let info = lastKnownPortInfo[port] {
            let name = info.dockerContainer?.name ?? info.process.name
            content.title = "\(name) · :\(port)"
            content.body = "localhost:\(port) stopped listening"
        } else {
            content.title = "Port \(port)"
            content.body = "localhost:\(port) stopped listening"
        }
        content.sound = .default
        lastKnownPortInfo.removeValue(forKey: port)

        let request = UNNotificationRequest(
            identifier: "seeport.removedport.\(port)",
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
            let attachment = try UNNotificationAttachment(
                identifier: "icon_\(pid)",
                url: tmpURL,
                options: [UNNotificationAttachmentOptionsTypeHintKey: "public.png"]
            )
            // UNNotificationAttachment moves the file; no manual cleanup needed
            return attachment
        } catch {
            return nil
        }
    }

    // MARK: - Actions

    func toggleFavorite(_ port: PortInfo) {
        let newState = Favorites.toggle(port.port)
        if let index = ports.firstIndex(where: { $0.port == port.port && $0.process.pid == port.process.pid }) {
            ports[index].isFavorite = newState
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
                dockerContainer: port.dockerContainer,
                projectPath: port.projectPath
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
                dockerContainer: port.dockerContainer,
                projectPath: port.projectPath
            )
        }
    }

    func hasOverride(_ port: PortInfo) -> Bool {
        CategoryOverrides.categoryFor(port.port) != nil
    }

    func dockerAction(_ action: String, containerId: String) async {
        let success: Bool
        switch action {
        case "stop":
            success = await dockerService.stop(id: containerId)
        case "start":
            success = await dockerService.start(id: containerId)
        case "restart":
            success = await dockerService.restart(id: containerId)
        default:
            return
        }
        if success {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func killProcess(_ port: PortInfo) async {
        let success: Bool
        if let container = port.dockerContainer {
            success = await dockerService.stop(id: container.id)
        } else {
            success = await ProcessService.kill(pid: port.process.pid)
        }
        if success {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func tabCount(for tab: FilterTab) -> Int {
        switch tab {
        case .all: return ports.count
        case .local: return ports.filter { $0.category != .system && $0.category != .other && $0.dockerContainer == nil }.count
        case .docker: return dockerContainers.count
        case .favorites: return ports.filter { $0.isFavorite }.count
        }
    }
}

import SwiftUI
import UserNotifications
import UniformTypeIdentifiers
import Sparkle

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case tools = "Tools"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .tools: return "wrench.and.screwdriver"
        case .about: return "info.circle"
        }
    }

    var iconFilled: String {
        switch self {
        case .general: return "gearshape.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: PortListViewModel
    @ObservedObject var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showBugReport = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar tabs
            HStack(spacing: 24) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    toolbarTab(tab)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general: generalTab
                    case .tools: toolsTab
                    case .about: aboutTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Constants.Colors.background)
        .sheet(isPresented: $showBugReport) {
            BugReportView()
        }
    }

    // MARK: - Toolbar Tab

    private func toolbarTab(_ tab: SettingsTab) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 4) {
                Image(systemName: selectedTab == tab ? tab.iconFilled : tab.icon)
                    .font(.system(size: 18))
                    .frame(width: 28, height: 28)
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundColor(selectedTab == tab ? .blue : Constants.Colors.textSecondary)
            .frame(width: 60, height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Scan
            flatSection("Scan") {
                flatToggleRow("Auto-refresh", isOn: $settings.autoRefreshEnabled)

                if settings.autoRefreshEnabled {
                    flatDivider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Refresh interval")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textSecondary)
                        HStack(spacing: 8) {
                            ForEach([5.0, 10.0, 20.0, 30.0], id: \.self) { interval in
                                intervalButton(interval)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }

            // Notifications
            flatSection("Notifications") {
                flatToggleRow("New port detected", isOn: $settings.notifyNewPort)
                flatDivider
                flatToggleRow("Port closed detected", isOn: $settings.notifyRemovedPort)
                flatDivider

                HStack {
                    Text("Status")
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Spacer()
                    Text(notificationStatusText)
                        .font(.system(size: 12))
                        .foregroundColor(notificationStatus == .authorized ? .green : .orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                flatDivider

                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.seeport.app") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("Open System Settings")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }

            // App
            flatSection("App") {
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack {
                        Text("Quit Seeport")
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
        }
        .onAppear { checkNotificationStatus() }
        .onChange(of: settings.autoRefreshEnabled) { _ in viewModel.applySettings() }
        .onChange(of: settings.refreshInterval) { _ in viewModel.applySettings() }
    }

    // MARK: - Tools Tab

    private var toolsTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            // External Editor
            VStack(alignment: .leading, spacing: 10) {
                Text("External Editor")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Constants.Colors.textPrimary)

                VStack(spacing: 0) {
                    toolPickerRow(selection: $settings.externalEditor, allCases: ExternalEditor.allCases)

                    if settings.externalEditor == .custom {
                        flatDivider
                        customToolConfig(
                            path: $settings.customEditorPath,
                            args: $settings.customEditorArgs,
                            pathPlaceholder: "Path to application"
                        )
                    }
                }
                .background(Constants.Colors.cardBackground)
                .cornerRadius(10)
            }

            // Shell
            VStack(alignment: .leading, spacing: 10) {
                Text("Shell")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Constants.Colors.textPrimary)

                VStack(spacing: 0) {
                    toolPickerRow(selection: $settings.shellApp, allCases: ShellApp.allCases)

                    if settings.shellApp == .custom {
                        flatDivider
                        customToolConfig(
                            path: $settings.customShellPath,
                            args: $settings.customShellArgs,
                            pathPlaceholder: "Path to executable"
                        )
                    }
                }
                .background(Constants.Colors.cardBackground)
                .cornerRadius(10)
            }
        }
        .onChange(of: settings.externalEditor) { newValue in
            if newValue == .custom && settings.customEditorPath.isEmpty {
                showAppPicker { url in settings.customEditorPath = url.path }
            }
        }
        .onChange(of: settings.shellApp) { newValue in
            if newValue == .custom && settings.customShellPath.isEmpty {
                showAppPicker { url in settings.customShellPath = url.path }
            }
        }
    }

    private func toolPickerRow<T: RawRepresentable & Hashable>(
        selection: Binding<T>, allCases: [T]
    ) -> some View where T.RawValue == String {
        Picker("", selection: selection) {
            ForEach(allCases, id: \.self) { item in
                Text(item.rawValue).tag(item)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(6)
    }

    private let fieldHeight: CGFloat = 32
    private let fieldCorner: CGFloat = 6
    private let fieldBg = Color.white.opacity(0.06)

    private func customToolConfig(path: Binding<String>, args: Binding<String>, pathPlaceholder: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Path
            VStack(alignment: .leading, spacing: 6) {
                Text("Path")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.Colors.textSecondary)
                HStack(spacing: 8) {
                    TextField(pathPlaceholder, text: path)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Constants.Colors.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(height: fieldHeight)
                        .background(fieldBg)
                        .cornerRadius(fieldCorner)
                        .onHover { h in if h { NSCursor.iBeam.push() } else { NSCursor.pop() } }

                    Button(action: {
                        showAppPicker { url in path.wrappedValue = url.path }
                    }) {
                        Text("Choose...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Constants.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .frame(height: fieldHeight)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(fieldCorner)
                    }
                    .buttonStyle(.plain)
                    .hoverCursor()
                }
            }

            // Arguments
            VStack(alignment: .leading, spacing: 6) {
                Text("Arguments")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.Colors.textSecondary)
                TextField("%TARGET_PATH%", text: args)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Constants.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: fieldHeight)
                    .background(fieldBg)
                    .cornerRadius(fieldCorner)
                    .onHover { h in if h { NSCursor.iBeam.push() } else { NSCursor.pop() } }
            }
        }
        .padding(16)
    }

    // MARK: - About Tab

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private static let cachedAppIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 512, height: 512)
            return image
        }
        return NSApp.applicationIconImage ?? NSImage()
    }()

    private var aboutTab: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Image(nsImage: Self.cachedAppIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 72, height: 72)
                    .cornerRadius(16)

                HStack(spacing: 0) {
                    Text("see").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    Text("port").font(.system(size: 18, weight: .bold)).foregroundColor(.blue)
                }

                Text("v\(appVersion)").font(.system(size: 11)).foregroundColor(Constants.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)

            flatSection("Links") {
                Button(action: {
                    if let url = URL(string: "https://github.com/clover4282/seeport") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("GitHub")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()

                flatDivider

                Button(action: { showBugReport = true }) {
                    HStack {
                        Text("Report a Bug")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "ladybug")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }

            flatSection("Support") {
                Button(action: {
                    if let url = URL(string: "https://buymeacoffee.com/clover4282") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack {
                        Text("Buy me a coffee")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Spacer()
                        BuyMeACoffeeLogo()
                            .frame(width: 16, height: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }

            flatSection("Updates") {
                Button(action: {
                    guard let updater = SeeportDelegate.updater else { return }
                    NSApp.setActivationPolicy(.regular)

                    let settingsWindow = SettingsWindowController.shared.window
                    settingsWindow?.level = .normal

                    NSApp.activate(ignoringOtherApps: true)
                    updater.checkForUpdates()

                    // Restore after Sparkle session ends (max 30s timeout)
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        for _ in 0..<60 {
                            guard updater.sessionInProgress else { break }
                            try? await Task.sleep(nanoseconds: 500_000_000)
                        }
                        await MainActor.run {
                            settingsWindow?.level = .floating
                            NSApp.setActivationPolicy(.accessory)
                        }
                    }
                }) {
                    HStack {
                        Text("Check for Updates")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
        }
    }

    // MARK: - Flat Design Components

    private func flatSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Constants.Colors.textPrimary)

            VStack(spacing: 0) {
                content()
            }
            .background(Constants.Colors.cardBackground)
            .cornerRadius(10)
        }
    }

    private var flatDivider: some View {
        Divider()
            .background(Color.white.opacity(0.08))
            .padding(.leading, 16)
    }

    private func flatToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func flatInfoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func flatPickerRow<T: RawRepresentable & Hashable>(
        _ title: String,
        selection: Binding<T>,
        allCases: [T]
    ) -> some View where T.RawValue == String {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            Picker("", selection: selection) {
                ForEach(allCases, id: \.self) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func intervalButton(_ interval: TimeInterval) -> some View {
        Button(action: { settings.refreshInterval = interval }) {
            Text("\(Int(interval))s")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(settings.refreshInterval == interval ? .white : Constants.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(settings.refreshInterval == interval ? Color.blue.opacity(0.5) : Color.white.opacity(0.06))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }

    private func shortcutRow(_ label: String, shortcut: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Constants.Colors.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.08))
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "Enabled"
        case .denied: return "Disabled"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not configured"
        @unknown default: return "Unknown"
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            DispatchQueue.main.async { notificationStatus = s.authorizationStatus }
        }
    }

    private func showAppPicker(onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { onSelect(url) }
    }

    private func appSelectRow(appPath: String, onSelect: @escaping (URL) -> Void) -> some View {
        let appName = appPath.isEmpty ? "Select App..." : URL(fileURLWithPath: appPath).deletingPathExtension().lastPathComponent
        let appIcon: NSImage? = appPath.isEmpty ? nil : NSWorkspace.shared.icon(forFile: appPath)

        return Button(action: { showAppPicker(onSelect: onSelect) }) {
            HStack(spacing: 10) {
                if let icon = appIcon {
                    Image(nsImage: icon).resizable().frame(width: 20, height: 20).cornerRadius(4)
                } else {
                    Image(systemName: "app.dashed").font(.system(size: 14)).foregroundColor(Constants.Colors.textSecondary).frame(width: 20, height: 20)
                }

                Text(appName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(appPath.isEmpty ? Constants.Colors.textSecondary : Constants.Colors.textPrimary)

                Spacer()

                Text("Change")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .hoverCursor()
    }
}

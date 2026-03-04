import SwiftUI
import UserNotifications

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case display = "Display"
    case license = "License"
    case about = "About"

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .display: return "paintbrush"
        case .license: return "key"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: PortListViewModel
    @ObservedObject var settings = SettingsManager.shared
    @ObservedObject var license = LicenseManager.shared
    @Binding var isPresented: Bool
    @State private var selectedTab: SettingsTab = .general
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var licenseKeyInput = ""
    @State private var showActivateField = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Constants.Colors.textPrimary)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
            .padding(.horizontal, Constants.Spacing.xlarge)
            .padding(.top, Constants.Spacing.xlarge)
            .padding(.bottom, Constants.Spacing.large)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    settingsTabButton(tab)
                }
            }
            .background(Constants.Colors.cardBackground)
            .cornerRadius(8)
            .padding(.horizontal, Constants.Spacing.xlarge)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.Spacing.xlarge) {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .display:
                        displayTab
                    case .license:
                        licenseTab
                    case .about:
                        aboutTab
                    }
                }
                .padding(Constants.Spacing.xlarge)
            }

            Spacer(minLength: 0)

            // Bottom bar
            Divider().background(Color.white.opacity(0.1))
            HStack {
                Button(action: {
                    settings.resetToDefaults()
                    viewModel.applySettings()
                }) {
                    Text("Reset to Defaults")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .hoverCursor()

                Spacer()

                Button(action: { isPresented = false }) {
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }
            .padding(.horizontal, Constants.Spacing.xlarge)
            .padding(.vertical, Constants.Spacing.large)
        }
        .frame(width: Constants.popoverWidth, height: Constants.popoverHeight)
        .background(Constants.Colors.background)
    }

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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Tab Button

    private func settingsTabButton(_ tab: SettingsTab) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tab.icon)
                .font(.system(size: 10))
            Text(tab.rawValue)
                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
        }
        .foregroundColor(selectedTab == tab ? .white : Constants.Colors.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(selectedTab == tab ? Color.blue.opacity(0.4) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { selectedTab = tab }
        .hoverCursor()
    }

    // MARK: - General Tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.xlarge) {
            // Scan section
            settingsSection("Scan") {
                settingsToggleRow(
                    icon: "arrow.clockwise",
                    title: "Auto-refresh",
                    subtitle: "Automatically scan ports at regular intervals",
                    isOn: $settings.autoRefreshEnabled
                )

                if settings.autoRefreshEnabled {
                    Divider().background(Color.white.opacity(0.06))

                    VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
                        Text("Refresh interval")
                            .font(.system(size: 12))
                            .foregroundColor(Constants.Colors.textSecondary)
                            .padding(.horizontal, Constants.Spacing.large)

                        HStack(spacing: Constants.Spacing.medium) {
                            ForEach([3.0, 5.0, 10.0, 30.0], id: \.self) { interval in
                                intervalButton(interval)
                            }
                        }
                        .padding(.horizontal, Constants.Spacing.large)
                    }
                    .padding(.vertical, Constants.Spacing.medium)
                }
            }

            // Notifications section
            settingsSection("Notifications") {
                HStack(spacing: Constants.Spacing.large) {
                    Image(systemName: notificationStatus == .authorized ? "bell.badge" : "bell.slash")
                        .font(.system(size: 14))
                        .foregroundColor(notificationStatus == .authorized ? .green : .orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notification status")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Text(notificationStatusText)
                            .font(.system(size: 10))
                            .foregroundColor(notificationStatus == .authorized ? .green : .orange)
                    }

                    Spacer()
                }
                .padding(.horizontal, Constants.Spacing.large)
                .padding(.vertical, 10)

                Divider().background(Color.white.opacity(0.06))

                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: Constants.Spacing.large) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .frame(width: 20)

                        Text("Open System Settings")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Constants.Colors.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 13))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }
                    .padding(.horizontal, Constants.Spacing.large)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .hoverCursor()
            }

            // Quit
            settingsSection("App") {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: Constants.Spacing.large) {
                        Image(systemName: "power")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 20)

                        Text("Quit Seeport")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.red)

                        Spacer()
                    }
                    .padding(.horizontal, Constants.Spacing.large)
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

    // MARK: - Display Tab

    private var displayTab: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.xlarge) {
            settingsSection("Appearance") {
                settingsToggleRow(
                    icon: "app.dashed",
                    title: "Process icons",
                    subtitle: "Show application icons next to port entries",
                    isOn: $settings.showProcessIcons
                )
            }

            settingsSection("Keyboard Shortcuts") {
                VStack(spacing: 0) {
                    shortcutRow("Refresh", shortcut: "\u{2318}R")
                    Divider().background(Color.white.opacity(0.06))
                    shortcutRow("Search", shortcut: "\u{2318}F")
                    Divider().background(Color.white.opacity(0.06))
                    shortcutRow("Quit", shortcut: "\u{2318}Q")
                }
            }
        }
    }

    // MARK: - License Tab

    private var licenseTab: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.xlarge) {
            // Status card
            licenseStatusCard

            // Actions
            switch license.status {
            case .trial, .expired:
                // Activate license
                settingsSection("Activate License") {
                    if showActivateField {
                        VStack(spacing: Constants.Spacing.medium) {
                            HStack(spacing: Constants.Spacing.medium) {
                                TextField("Enter license key", text: $licenseKeyInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Constants.Colors.textPrimary)
                                    .padding(8)
                                    .background(Constants.Colors.searchBackground)
                                    .cornerRadius(6)
                                    .onHover { hovering in
                                        if hovering { NSCursor.iBeam.push() }
                                        else { NSCursor.pop() }
                                    }

                                Button(action: {
                                    Task {
                                        await license.activate(key: licenseKeyInput)
                                        if case .active = license.status {
                                            licenseKeyInput = ""
                                            showActivateField = false
                                        }
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if license.isActivating {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .frame(width: 12, height: 12)
                                        }
                                        Text(license.isActivating ? "Verifying..." : "Activate")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(license.isActivating ? Color.gray : Color.blue)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                .hoverCursor()
                                .disabled(license.isActivating)
                            }

                            if let error = license.activationError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(Constants.Spacing.large)
                    } else {
                        Button(action: { showActivateField = true }) {
                            HStack(spacing: Constants.Spacing.large) {
                                Image(systemName: "key")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                    .frame(width: 20)

                                Text("Enter License Key")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Constants.Colors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(Constants.Colors.textSecondary)
                            }
                            .padding(.horizontal, Constants.Spacing.large)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .hoverCursor()
                    }
                }

                // Purchase via Paddle
                purchaseSection

            case .active:
                settingsSection("Manage") {
                    Button(action: { license.deactivate() }) {
                        HStack(spacing: Constants.Spacing.large) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                                .frame(width: 20)

                            Text("Reset License")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Constants.Colors.textPrimary)

                            Spacer()
                        }
                        .padding(.horizontal, Constants.Spacing.large)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .hoverCursor()
                }
            }

            // About licensing
            VStack(alignment: .leading, spacing: Constants.Spacing.small) {
                Text("About Licensing")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Constants.Colors.textPrimary)
                Text("seeport offers a 30-day free trial. After that, a one-time purchase via Paddle grants you a perpetual license with lifetime updates. Your license is tied to this device.")
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineSpacing(2)
            }
            .padding(.top, Constants.Spacing.small)
        }
    }

    private var purchaseSection: some View {
        settingsSection("Purchase") {
            Button(action: {
                if let url = URL(string: PaddleConfig.checkoutURL) {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: Constants.Spacing.large) {
                    Image(systemName: "cart")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Purchase a License")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Constants.Colors.textPrimary)
                        Text("One-time purchase, lifetime updates via Paddle")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Colors.textSecondary)
                }
                .padding(.horizontal, Constants.Spacing.large)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .hoverCursor()
        }
    }

    private var licenseStatusCard: some View {
        HStack(spacing: Constants.Spacing.large) {
            // Status icon
            Group {
                switch license.status {
                case .active:
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                case .trial:
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                case .expired:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                switch license.status {
                case .active:
                    Text("License Active")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text(license.maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Constants.Colors.textSecondary)
                case .trial(let days):
                    Text("Free Trial")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text("\(days) days remaining")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                case .expired:
                    Text("Trial Expired")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Constants.Colors.textPrimary)
                    Text("Please purchase a license to continue")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            Spacer()
        }
        .padding(Constants.Spacing.large)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Constants.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(statusBorderColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var statusBorderColor: Color {
        switch license.status {
        case .active: return .green
        case .trial: return .blue
        case .expired: return .red
        }
    }

    // MARK: - About Tab

    private var aboutTab: some View {
        VStack(spacing: Constants.Spacing.xlarge) {
            // App info
            VStack(spacing: Constants.Spacing.medium) {
                Image(systemName: "network")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 0) {
                    Text("see")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text("port")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                }

                Text("v1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(Constants.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.xlarge)

            settingsSection("Info") {
                aboutRow("Developer", value: "clover")
                Divider().background(Color.white.opacity(0.06))
                aboutRow("Platform", value: "macOS 13+")
                Divider().background(Color.white.opacity(0.06))
                aboutRow("Framework", value: "SwiftUI")
            }

            settingsSection("Data") {
                aboutRow("Favorites", value: "\(Favorites.load().count) ports")
                Divider().background(Color.white.opacity(0.06))
                aboutRow("Overrides", value: "\(CategoryOverrides.load().count) ports")
            }
        }
    }

    // MARK: - Reusable Components

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.medium) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Constants.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content()
            }
            .background(Constants.Colors.cardBackground)
            .cornerRadius(10)
        }
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Constants.Spacing.large) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Constants.Colors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.8)
                .frame(width: 40)
        }
        .padding(.horizontal, Constants.Spacing.large)
        .padding(.vertical, 10)
    }

    private func intervalButton(_ interval: TimeInterval) -> some View {
        Button(action: { settings.refreshInterval = interval }) {
            Text("\(Int(interval))s")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(settings.refreshInterval == interval ? .white : Constants.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    settings.refreshInterval == interval
                        ? Color.blue.opacity(0.5)
                        : Color.white.opacity(0.06)
                )
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
        .padding(.horizontal, Constants.Spacing.large)
        .padding(.vertical, 8)
    }

    private func aboutRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Constants.Colors.textPrimary)
            Spacer()
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(Constants.Colors.textSecondary)
        }
        .padding(.horizontal, Constants.Spacing.large)
        .padding(.vertical, 8)
    }
}

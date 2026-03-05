import SwiftUI
import AppKit

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func open(viewModel: PortListViewModel) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: settingsView)

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Seeport Settings"
        w.contentView = hostingView
        w.backgroundColor = NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1.0)
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.center()
        w.level = .floating
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = w
    }
}

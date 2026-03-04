import SwiftUI
import AppKit

@main
struct SeeportApp: App {
    @NSApplicationDelegateAdaptor(SeeportDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("seeport", systemImage: Constants.menuBarIcon) {
            MainPopoverView()
        }
        .menuBarExtraStyle(.window)
    }
}

final class SeeportDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = Self.makeAppIcon()
    }

    private static func makeAppIcon() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        // Background rounded rect
        let bgRect = NSRect(x: 20, y: 20, width: size - 40, height: size - 40)
        let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 100, yRadius: 100)
        NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0).setFill()
        bgPath.fill()

        // Gradient overlay
        if let gradient = NSGradient(
            starting: NSColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 0.25),
            ending: NSColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 0.1)
        ) {
            gradient.draw(in: bgPath, angle: -45)
        }

        // Network icon
        if let symbol = NSImage(systemSymbolName: "network", accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 180, weight: .medium)
                .applying(.init(paletteColors: [.white]))
            let rendered = symbol.withSymbolConfiguration(config) ?? symbol
            let w = rendered.size.width
            let h = rendered.size.height
            rendered.draw(
                in: NSRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h),
                from: .zero, operation: .sourceOver, fraction: 0.9
            )
        }

        // Accent border
        let ringRect = NSRect(x: 24, y: 24, width: size - 48, height: size - 48)
        let ringPath = NSBezierPath(roundedRect: ringRect, xRadius: 98, yRadius: 98)
        ringPath.lineWidth = 4
        NSColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.5).setStroke()
        ringPath.stroke()

        image.unlockFocus()
        return image
    }
}

import SwiftUI
import AppKit
import UserNotifications
import Sparkle

@main
struct SeeportApp: App {
    @NSApplicationDelegateAdaptor(SeeportDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MainPopoverView()
        } label: {
            Image(nsImage: SeeportDelegate.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}

final class SeeportDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static private(set) var updaterController: SPUStandardUpdaterController?

    static var updater: SPUUpdater? {
        updaterController?.updater
    }

    static let menuBarIcon: NSImage = makeMenuBarIcon()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.applicationIconImage = Self.makeAppIcon()
        UNUserNotificationCenter.current().delegate = self

        Self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    static func makeMenuBarIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let cx = size / 2
        let color = NSColor.black

        // Ring at top
        let ringRadius: CGFloat = 2.2
        let ringCenter = NSPoint(x: cx, y: 15.5)
        let ring = NSBezierPath(
            ovalIn: NSRect(
                x: ringCenter.x - ringRadius,
                y: ringCenter.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
        )
        ring.lineWidth = 1.4
        color.setStroke()
        ring.stroke()

        // Shaft (vertical line)
        let shaft = NSBezierPath()
        shaft.move(to: NSPoint(x: cx, y: 13.5))
        shaft.line(to: NSPoint(x: cx, y: 3.5))
        shaft.lineWidth = 1.6
        shaft.lineCapStyle = .round
        color.setStroke()
        shaft.stroke()

        // Cross bar
        let bar = NSBezierPath()
        bar.move(to: NSPoint(x: cx - 4, y: 11))
        bar.line(to: NSPoint(x: cx + 4, y: 11))
        bar.lineWidth = 1.6
        bar.lineCapStyle = .round
        color.setStroke()
        bar.stroke()

        // Left fluke
        let leftFluke = NSBezierPath()
        leftFluke.move(to: NSPoint(x: cx, y: 3.5))
        leftFluke.curve(
            to: NSPoint(x: cx - 5.5, y: 7),
            controlPoint1: NSPoint(x: cx - 0.5, y: 1.5),
            controlPoint2: NSPoint(x: cx - 5.5, y: 2)
        )
        leftFluke.lineWidth = 1.4
        leftFluke.lineCapStyle = .round
        color.setStroke()
        leftFluke.stroke()

        // Left arrowhead
        let la = NSBezierPath()
        la.move(to: NSPoint(x: cx - 5.5, y: 7))
        la.line(to: NSPoint(x: cx - 6.8, y: 5))
        la.lineWidth = 1.4
        la.lineCapStyle = .round
        color.setStroke()
        la.stroke()

        // Right fluke
        let rightFluke = NSBezierPath()
        rightFluke.move(to: NSPoint(x: cx, y: 3.5))
        rightFluke.curve(
            to: NSPoint(x: cx + 5.5, y: 7),
            controlPoint1: NSPoint(x: cx + 0.5, y: 1.5),
            controlPoint2: NSPoint(x: cx + 5.5, y: 2)
        )
        rightFluke.lineWidth = 1.4
        rightFluke.lineCapStyle = .round
        color.setStroke()
        rightFluke.stroke()

        // Right arrowhead
        let ra = NSBezierPath()
        ra.move(to: NSPoint(x: cx + 5.5, y: 7))
        ra.line(to: NSPoint(x: cx + 6.8, y: 5))
        ra.lineWidth = 1.4
        ra.lineCapStyle = .round
        color.setStroke()
        ra.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private static func makeAppIcon() -> NSImage {
        // Load from bundle's AppIcon.icns
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        // Fallback: generic anchor icon
        return NSImage(systemSymbolName: "anchor", accessibilityDescription: "Seeport") ?? NSImage()
    }
}

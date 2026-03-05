#!/usr/bin/env swift
// Generates AppIcon.icns from programmatic drawing
// Usage: swift GenerateIcon.swift <output-path>

import AppKit

let size: CGFloat = 1024
let cx = size / 2
let cy = size / 2
let s = size / 512  // scale factor

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background rounded rect
let bgRect = NSRect(x: 20 * s, y: 20 * s, width: size - 40 * s, height: size - 40 * s)
let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: 100 * s, yRadius: 100 * s)

// White background
NSColor.white.setFill()
bgPath.fill()

// ── Anchor shape ──
let anchorColor = NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
let glowColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.1)
let lineW: CGFloat = 22 * s

// Anchor shaft (vertical line)
let shaftTop = cy + 110 * s
let shaftBottom = cy - 100 * s
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: cx, y: shaftTop))
shaft.line(to: NSPoint(x: cx, y: shaftBottom))
shaft.lineCapStyle = .round
glowColor.setStroke()
shaft.lineWidth = lineW + 12 * s
shaft.stroke()
anchorColor.setStroke()
shaft.lineWidth = lineW
shaft.stroke()

// Cross bar (horizontal)
let barY = shaftTop - 50 * s
let barHalf: CGFloat = 70 * s
let bar = NSBezierPath()
bar.move(to: NSPoint(x: cx - barHalf, y: barY))
bar.line(to: NSPoint(x: cx + barHalf, y: barY))
bar.lineCapStyle = .round
glowColor.setStroke()
bar.lineWidth = lineW + 12 * s
bar.stroke()
anchorColor.setStroke()
bar.lineWidth = lineW
bar.stroke()

// Ring at top
let ringRadius: CGFloat = 32 * s
let ringCenter = NSPoint(x: cx, y: shaftTop + ringRadius + 4 * s)
let ring = NSBezierPath(
    ovalIn: NSRect(
        x: ringCenter.x - ringRadius,
        y: ringCenter.y - ringRadius,
        width: ringRadius * 2,
        height: ringRadius * 2
    )
)
glowColor.setStroke()
ring.lineWidth = (lineW + 8 * s)
ring.stroke()
anchorColor.setStroke()
ring.lineWidth = (lineW - 4 * s)
ring.stroke()

// Left fluke (curved arm)
let flukeW: CGFloat = lineW - 2 * s
let leftFluke = NSBezierPath()
leftFluke.move(to: NSPoint(x: cx, y: shaftBottom))
leftFluke.curve(
    to: NSPoint(x: cx - 120 * s, y: cy - 10 * s),
    controlPoint1: NSPoint(x: cx - 10 * s, y: shaftBottom - 40 * s),
    controlPoint2: NSPoint(x: cx - 120 * s, y: shaftBottom - 20 * s)
)
leftFluke.lineCapStyle = .round
glowColor.setStroke()
leftFluke.lineWidth = flukeW + 12 * s
leftFluke.stroke()
anchorColor.setStroke()
leftFluke.lineWidth = flukeW
leftFluke.stroke()

// Left fluke arrowhead
let leftArrow = NSBezierPath()
leftArrow.move(to: NSPoint(x: cx - 120 * s, y: cy - 10 * s))
leftArrow.line(to: NSPoint(x: cx - 140 * s, y: cy - 40 * s))
leftArrow.lineCapStyle = .round
anchorColor.setStroke()
leftArrow.lineWidth = flukeW
leftArrow.stroke()

// Right fluke (curved arm)
let rightFluke = NSBezierPath()
rightFluke.move(to: NSPoint(x: cx, y: shaftBottom))
rightFluke.curve(
    to: NSPoint(x: cx + 120 * s, y: cy - 10 * s),
    controlPoint1: NSPoint(x: cx + 10 * s, y: shaftBottom - 40 * s),
    controlPoint2: NSPoint(x: cx + 120 * s, y: shaftBottom - 20 * s)
)
rightFluke.lineCapStyle = .round
glowColor.setStroke()
rightFluke.lineWidth = flukeW + 12 * s
rightFluke.stroke()
anchorColor.setStroke()
rightFluke.lineWidth = flukeW
rightFluke.stroke()

// Right fluke arrowhead
let rightArrow = NSBezierPath()
rightArrow.move(to: NSPoint(x: cx + 120 * s, y: cy - 10 * s))
rightArrow.line(to: NSPoint(x: cx + 140 * s, y: cy - 40 * s))
rightArrow.lineCapStyle = .round
anchorColor.setStroke()
rightArrow.lineWidth = flukeW
rightArrow.stroke()

// Subtle wave lines at bottom
let waveColor = NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.08)
for i in 0..<3 {
    let waveY = CGFloat(Double(100 + i * 28) * Double(s))
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 60 * s, y: waveY))
    wave.curve(
        to: NSPoint(x: size - 60 * s, y: waveY),
        controlPoint1: NSPoint(x: size * 0.3, y: waveY + 18 * s),
        controlPoint2: NSPoint(x: size * 0.7, y: waveY - 18 * s)
    )
    wave.lineWidth = 4 * s
    waveColor.setStroke()
    wave.stroke()
}

// Accent border
let borderRect = NSRect(x: 24 * s, y: 24 * s, width: size - 48 * s, height: size - 48 * s)
let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 98 * s, yRadius: 98 * s)
borderPath.lineWidth = 3 * s
NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.1).setStroke()
borderPath.stroke()

image.unlockFocus()

// Export to PNG then convert to icns
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to create image data\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon"
let pngPath = "/tmp/seeport_icon_1024.png"
try! pngData.write(to: URL(fileURLWithPath: pngPath))

// Create iconset
let iconsetPath = "/tmp/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes
let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in sizes {
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
               from: .zero, operation: .copy, fraction: 1.0)
    resized.unlockFocus()
    guard let t = resized.tiffRepresentation,
          let b = NSBitmapImageRep(data: t),
          let d = b.representation(using: .png, properties: [:]) else { continue }
    try! d.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name)"))
}

// Run iconutil to create .icns
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetPath, "-o", outputPath + ".icns"]
try! proc.run()
proc.waitUntilExit()

if proc.terminationStatus == 0 {
    print("Icon generated: \(outputPath).icns")
} else {
    fputs("iconutil failed\n", stderr)
    exit(1)
}

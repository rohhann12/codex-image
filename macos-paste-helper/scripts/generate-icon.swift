#!/usr/bin/env swift

import AppKit

let outputPath = CommandLine.arguments.dropFirst().first ?? "./dist/PastePath.png"
let outputURL = URL(fileURLWithPath: outputPath)
let size = NSSize(width: 1024, height: 1024)

let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let background = NSColor(calibratedRed: 0.05, green: 0.08, blue: 0.13, alpha: 1.0)
background.setFill()
NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220).fill()

let glowRect = NSRect(x: 84, y: 84, width: 856, height: 856)
let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.00, green: 0.78, blue: 0.70, alpha: 0.28),
    NSColor(calibratedRed: 0.24, green: 0.54, blue: 1.00, alpha: 0.12),
    NSColor(calibratedRed: 0.97, green: 0.55, blue: 0.16, alpha: 0.18)
])!
glow.draw(in: NSBezierPath(roundedRect: glowRect, xRadius: 200, yRadius: 200), angle: -30)

let panelRect = NSRect(x: 132, y: 176, width: 760, height: 672)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 92, yRadius: 92)
NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.16, alpha: 0.94).setFill()
panelPath.fill()

NSColor(calibratedWhite: 1.0, alpha: 0.07).setStroke()
panelPath.lineWidth = 8
panelPath.stroke()

let tabRect = NSRect(x: 182, y: 720, width: 220, height: 54)
let tabPath = NSBezierPath(roundedRect: tabRect, xRadius: 26, yRadius: 26)
NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.24, alpha: 1).setFill()
tabPath.fill()

let dotColors: [NSColor] = [
    NSColor(calibratedRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
    NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 1),
    NSColor(calibratedRed: 0.18, green: 0.84, blue: 0.44, alpha: 1)
]
for (index, color) in dotColors.enumerated() {
    color.setFill()
    let dotRect = NSRect(x: 188 + (index * 28), y: 736, width: 16, height: 16)
    NSBezierPath(ovalIn: dotRect).fill()
}

let terminalFrame = NSRect(x: 188, y: 250, width: 648, height: 430)
let terminalPath = NSBezierPath(roundedRect: terminalFrame, xRadius: 52, yRadius: 52)
NSColor(calibratedRed: 0.04, green: 0.06, blue: 0.10, alpha: 1).setFill()
terminalPath.fill()

let neon = NSColor(calibratedRed: 0.12, green: 0.92, blue: 0.82, alpha: 1.0)
let warm = NSColor(calibratedRed: 1.00, green: 0.61, blue: 0.20, alpha: 1.0)

let lineAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 78, weight: .bold),
    .foregroundColor: neon
]

let line2Attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 64, weight: .semibold),
    .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1)
]

let line3Attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 52, weight: .medium),
    .foregroundColor: warm
]

NSString(string: "› paste").draw(at: NSPoint(x: 252, y: 542), withAttributes: lineAttrs)
NSString(string: "/copied/image.png").draw(at: NSPoint(x: 252, y: 432), withAttributes: line2Attrs)
NSString(string: "cmd+v -> path").draw(at: NSPoint(x: 252, y: 338), withAttributes: line3Attrs)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 700, y: 588))
arrow.line(to: NSPoint(x: 798, y: 656))
arrow.line(to: NSPoint(x: 768, y: 676))
arrow.line(to: NSPoint(x: 850, y: 696))
arrow.line(to: NSPoint(x: 810, y: 622))
arrow.line(to: NSPoint(x: 780, y: 642))
arrow.line(to: NSPoint(x: 682, y: 572))
arrow.close()
neon.setFill()
arrow.fill()

let badgeRect = NSRect(x: 664, y: 132, width: 176, height: 76)
let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 38, yRadius: 38)
NSColor(calibratedRed: 0.12, green: 0.17, blue: 0.24, alpha: 1).setFill()
badgePath.fill()

let badgeAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor.white
]
NSString(string: "TUI").draw(at: NSPoint(x: 712, y: 152), withAttributes: badgeAttrs)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to generate icon image\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
print("Generated icon at \(outputURL.path)")

#!/usr/bin/env swift

// Generates AppIcon.icns from a SF Symbol on a colored rounded square background.
// Run: swift scripts/generate-icon.swift
// Output: resources/AppIcon.icns

import AppKit
import Foundation

// "moon.stars.fill" 跟 Owly 主题契合 —— 月亮 + 繁星 + 夜行不睡
let symbolName = "moon.stars.fill"
// 深紫夜空色 (Indigo 950 风)
let bgColor = NSColor(calibratedRed: 0.18, green: 0.13, blue: 0.42, alpha: 1.0)
let fgColor = NSColor.white

let projectRoot = FileManager.default.currentDirectoryPath as NSString
let iconsetDir: NSString = projectRoot.appendingPathComponent("build/AppIcon.iconset") as NSString
let outputIcns = projectRoot.appendingPathComponent("resources/AppIcon.icns")

let sizes: [(filename: String, pixels: Int)] = [
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

let fm = FileManager.default
try? fm.removeItem(atPath: iconsetDir as String)
try fm.createDirectory(atPath: iconsetDir as String, withIntermediateDirectories: true)

func renderIcon(pixels: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let radius = CGFloat(pixels) * 0.225
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bgColor.setFill()
    bgPath.fill()

    let symbolFontSize = CGFloat(pixels) * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolFontSize, weight: .semibold)
    if let raw = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
        let symbolImage = raw.withSymbolConfiguration(config) ?? raw
        symbolImage.isTemplate = true

        let symRect = NSRect(
            x: (CGFloat(pixels) - symbolImage.size.width) / 2,
            y: (CGFloat(pixels) - symbolImage.size.height) / 2,
            width: symbolImage.size.width,
            height: symbolImage.size.height
        )

        // Tint template image white.
        if let cgImage = symbolImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.clip(to: symRect, mask: cgImage)
            fgColor.setFill()
            ctx.fill(symRect)
            ctx.restoreGState()
        }
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to path: String) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "icon", code: 1)
    }
    try png.write(to: URL(fileURLWithPath: path))
}

for (name, pixels) in sizes {
    let img = renderIcon(pixels: pixels)
    let path = iconsetDir.appendingPathComponent(name)
    try writePNG(img, to: path)
    print("  generated \(name) (\(pixels)x\(pixels))")
}

print("==> iconutil -c icns ...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetDir as String, "-o", outputIcns]
try task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ wrote \(outputIcns)")
} else {
    print("❌ iconutil failed (exit \(task.terminationStatus))")
    exit(1)
}

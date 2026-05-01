#!/usr/bin/env swift

// Generates AppIcon.icns with a geometric stylized owl on a deep night-sky
// gradient. No SF Symbol dependency — every shape is hand-rolled with
// Core Graphics so the result is identical across macOS versions.
//
// Run: swift scripts/generate-icon.swift
// Output: resources/AppIcon.icns

import AppKit
import Foundation

// === Color palette ===
let bgGradientTop = NSColor(calibratedRed: 0.34, green: 0.22, blue: 0.62, alpha: 1.0)   // Indigo 600
let bgGradientBot = NSColor(calibratedRed: 0.10, green: 0.07, blue: 0.28, alpha: 1.0)   // Indigo 950
let bodyTop       = NSColor(calibratedRed: 0.97, green: 0.88, blue: 0.65, alpha: 1.0)   // Cream
let bodyBot       = NSColor(calibratedRed: 0.82, green: 0.65, blue: 0.36, alpha: 1.0)   // Tan
let eyeWhite      = NSColor.white
let pupilColor    = NSColor(calibratedRed: 0.10, green: 0.07, blue: 0.20, alpha: 1.0)
let beakColor     = NSColor(calibratedRed: 1.00, green: 0.62, blue: 0.18, alpha: 1.0)   // Amber
let starColor     = NSColor.white

// === Layout (in 1024x1024 reference space) ===
let canvas: CGFloat = 1024
let cornerR: CGFloat = canvas * 0.225

// Owl center is shifted slightly down so the ear tufts have headroom.
let ownerCenter = NSPoint(x: 512, y: 480)
let headW: CGFloat = 620
let headH: CGFloat = 660

// Ears — base sits well inside the head ellipse so they look "rooted",
// not floating. Tips are still clamped within the icon's safe area.
let earBaseY: CGFloat = ownerCenter.y + 230     // 80px below the head's top
let earTipY: CGFloat = ownerCenter.y + 405      // tip stays under canvas margin
let earOffsetX: CGFloat = 175                    // horizontal distance from center
let earHalfWidth: CGFloat = 85                   // wider base for a sturdier look

// Eyes
let eyeY: CGFloat = ownerCenter.y + 90
let eyeOffsetX: CGFloat = 142
let eyeR: CGFloat = 142

// Pupils (slightly converged inward for personality)
let pupilR: CGFloat = 68
let pupilConvergeX: CGFloat = 22                 // pupils nudged toward center
let pupilNudgeY: CGFloat = -8                    // and a hair down — wide-eyed alert look

// Pupil highlight
let highlightR: CGFloat = 22
let highlightDX: CGFloat = 24
let highlightDY: CGFloat = 26

// Beak
let beakTopY: CGFloat = ownerCenter.y - 70
let beakTipY: CGFloat = ownerCenter.y - 175
let beakHalfWidth: CGFloat = 38

// Decorative background stars (x, y, radius, alpha) in canvas-space
let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
    (160, 820, 7, 0.65),
    (310, 900, 5, 0.45),
    (240, 700, 4, 0.40),
    (820, 870, 6, 0.55),
    (910, 760, 4, 0.40),
    (130, 540, 5, 0.45),
    (880, 500, 4, 0.40),
    (760, 220, 5, 0.50),
    (200, 200, 6, 0.55),
]

// === Output configuration ===
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

// Helper: scale a canvas-space point/rect/value down to pixel-space.
func renderIcon(pixels: Int) -> NSImage {
    let s = CGFloat(pixels) / canvas    // canvas → pixel scale
    let pt: (CGFloat, CGFloat) -> NSPoint = { NSPoint(x: $0 * s, y: $1 * s) }

    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerR * s, yRadius: cornerR * s)

    NSGraphicsContext.current?.saveGraphicsState()
    bgPath.addClip()

    // 1. Background gradient (top → bottom)
    let bgGrad = NSGradient(starting: bgGradientTop, ending: bgGradientBot)!
    bgGrad.draw(in: rect, angle: -90)

    // 2. Decorative stars (skip on tiny sizes — they become noise)
    if pixels >= 64 {
        for (x, y, r, a) in stars {
            starColor.withAlphaComponent(a).setFill()
            let starRect = NSRect(
                x: (x - r) * s,
                y: (y - r) * s,
                width: r * 2 * s,
                height: r * 2 * s
            )
            NSBezierPath(ovalIn: starRect).fill()
        }
    }

    // 3. Ear tufts (drawn first so head ellipse sits on top)
    let bodyShadowFill = bodyBot
    bodyShadowFill.setFill()
    for sign: CGFloat in [-1, 1] {
        let path = NSBezierPath()
        let cx = ownerCenter.x + sign * earOffsetX
        path.move(to: pt(cx - earHalfWidth, earBaseY))
        path.line(to: pt(cx + earHalfWidth, earBaseY))
        path.line(to: pt(cx, earTipY))
        path.close()
        path.fill()
    }

    // 4. Owl head/body — single ellipse with vertical gradient
    let headRect = NSRect(
        x: (ownerCenter.x - headW / 2) * s,
        y: (ownerCenter.y - headH / 2) * s,
        width: headW * s,
        height: headH * s
    )
    let headPath = NSBezierPath(ovalIn: headRect)

    NSGraphicsContext.current?.saveGraphicsState()
    headPath.addClip()
    let bodyGrad = NSGradient(starting: bodyTop, ending: bodyBot)!
    bodyGrad.draw(in: headRect, angle: -90)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Subtle facial disc — slight darker ring at the bottom of the head to
    // suggest a "facial disc" shape that real owls have. Skipped on tiny
    // sizes where it just becomes noise.
    if pixels >= 64 {
        let discCenter = NSPoint(x: ownerCenter.x, y: ownerCenter.y - 30)
        let discR: CGFloat = 240
        bodyTop.withAlphaComponent(0.55).setFill()
        let discRect = NSRect(
            x: (discCenter.x - discR) * s,
            y: (discCenter.y - discR) * s,
            width: discR * 2 * s,
            height: discR * 2 * s
        )
        NSBezierPath(ovalIn: discRect).fill()
    }

    // 5. Eyes — two big white discs
    eyeWhite.setFill()
    for sign: CGFloat in [-1, 1] {
        let cx = ownerCenter.x + sign * eyeOffsetX
        let r = eyeR
        let eyeRect = NSRect(
            x: (cx - r) * s,
            y: (eyeY - r) * s,
            width: r * 2 * s,
            height: r * 2 * s
        )
        NSBezierPath(ovalIn: eyeRect).fill()
    }

    // 6. Pupils — black, nudged inward toward center for "looking at you"
    pupilColor.setFill()
    for sign: CGFloat in [-1, 1] {
        let pupilCx = ownerCenter.x + sign * (eyeOffsetX - pupilConvergeX)
        let pupilCy = eyeY + pupilNudgeY
        let r = pupilR
        let pupilRect = NSRect(
            x: (pupilCx - r) * s,
            y: (pupilCy - r) * s,
            width: r * 2 * s,
            height: r * 2 * s
        )
        NSBezierPath(ovalIn: pupilRect).fill()
    }

    // 7. Pupil highlight — small white dot, top-right of each pupil
    if pixels >= 32 {
        eyeWhite.setFill()
        for sign: CGFloat in [-1, 1] {
            let pupilCx = ownerCenter.x + sign * (eyeOffsetX - pupilConvergeX)
            let pupilCy = eyeY + pupilNudgeY
            let hlCx = pupilCx + highlightDX
            let hlCy = pupilCy + highlightDY
            let r = highlightR
            let hlRect = NSRect(
                x: (hlCx - r) * s,
                y: (hlCy - r) * s,
                width: r * 2 * s,
                height: r * 2 * s
            )
            NSBezierPath(ovalIn: hlRect).fill()
        }
    }

    // 8. Beak — amber triangle pointing down, between & below the eyes
    beakColor.setFill()
    let beakPath = NSBezierPath()
    beakPath.move(to: pt(ownerCenter.x - beakHalfWidth, beakTopY))
    beakPath.line(to: pt(ownerCenter.x + beakHalfWidth, beakTopY))
    beakPath.line(to: pt(ownerCenter.x, beakTipY))
    beakPath.close()
    beakPath.fill()

    NSGraphicsContext.current?.restoreGraphicsState()

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

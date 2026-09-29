#!/usr/bin/env swift
// Generates rexTrackpad/Assets.xcassets/AppIcon.appiconset.
//
//     swift scripts/make-icon.swift
//
// The icon is drawn with Core Graphics so it can be tweaked and regenerated
// without an image editor: a blue squircle with a trackpad, three fingertips
// and a swipe arrow.

import AppKit
import CoreGraphics

let canvas: CGFloat = 1024

func drawIcon(in ctx: CGContext) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    // macOS icon grid: 824 pt body inset by 100 pt, continuous-corner radius ~185.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.9, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Background gradient (top: sky blue → bottom: indigo).
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.36, green: 0.62, blue: 1.00, alpha: 1),
            CGColor(red: 0.24, green: 0.27, blue: 0.86, alpha: 1),
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Trackpad.
    let pad = CGRect(x: 232, y: 262, width: 560, height: 420)
    let padPath = CGPath(roundedRect: pad, cornerWidth: 64, cornerHeight: 64, transform: nil)
    ctx.addPath(padPath)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.16))
    ctx.fillPath()
    ctx.addPath(padPath)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
    ctx.setLineWidth(22)
    ctx.strokePath()

    // Three fingertips, side by side like a hand (middle finger a little higher).
    let white = CGColor(gray: 1, alpha: 1)
    let tipRadius: CGFloat = 46
    let tips = [CGPoint(x: 398, y: 540), CGPoint(x: 512, y: 572), CGPoint(x: 626, y: 540)]
    for tip in tips {
        ctx.addEllipse(in: CGRect(x: tip.x - tipRadius, y: tip.y - tipRadius, width: tipRadius * 2, height: tipRadius * 2))
    }
    ctx.setFillColor(white)
    ctx.fillPath()

    // Swipe arrow below the fingertips.
    let arrowY: CGFloat = 392
    ctx.setStrokeColor(white)
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 372, y: arrowY))
    ctx.addLine(to: CGPoint(x: 640, y: arrowY))
    ctx.strokePath()
    ctx.move(to: CGPoint(x: 580, y: arrowY + 58))
    ctx.addLine(to: CGPoint(x: 648, y: arrowY))
    ctx.addLine(to: CGPoint(x: 580, y: arrowY - 58))
    ctx.strokePath()
}

func render(size: Int) -> Data {
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let output = URL(fileURLWithPath: "rexTrackpad/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        try render(size: pixels).write(to: output.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("Contents.json"))

let catalog: [String: Any] = ["info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: catalog, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.deletingLastPathComponent().appendingPathComponent("Contents.json"))

print("wrote \(images.count) images to \(output.path)")

// Renders Chronobar's placeholder app icon: a stopwatch on a rounded-square tile.
// It needs only the Command Line Tools. The PNGs it writes are committed, and
// scripts/bundle-app.sh turns them into Chronobar.icns with `iconutil`.
//
// To regenerate the icon after changing this file:
//
//   swift scripts/make-icon.swift packaging/icon/AppIcon.iconset
//
// Each size is drawn directly at its pixel size rather than scaled down from 1024px, and the
// smallest sizes drop the tick marks and thicken the strokes so the icon still reads at 16px.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift scripts/make-icon.swift <output.iconset>\n".utf8))
    exit(2)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        colorSpace: space,
        components: [
            CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
        ])!
}

let tileTop = rgb(0x2F6BD8)
let tileBottom = rgb(0x1B3C8F)
let face = rgb(0xFFFFFF)
let rim = rgb(0x0F2457)
let elapsed = rgb(0xFF8A2A)
let ink = rgb(0x14213D)

/// Draws the icon into a square context `px` pixels wide. All geometry is in a 1024-unit grid.
func draw(_ ctx: CGContext, px: Int) {
    let s = CGFloat(px) / 1024
    ctx.scaleBy(x: s, y: s)
    let small = px <= 32
    let tiny = px <= 16

    // Tile: the macOS icon grid's 824-unit rounded square, centred, with a soft drop shadow.
    let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tile = CGPath(roundedRect: tileRect, cornerWidth: 185, cornerHeight: 185, transform: nil)
    if !small {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.35))
        ctx.addPath(tile)
        ctx.setFillColor(tileBottom)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [tileTop, tileBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Stopwatch: crown and side button above a round face.
    let centre = CGPoint(x: 512, y: tiny ? 458 : 488)
    let radius: CGFloat = tiny ? 300 : 290
    let rimWidth: CGFloat = tiny ? 70 : (small ? 56 : 40)

    ctx.setFillColor(face)
    let stemWidth: CGFloat = tiny ? 120 : 96
    ctx.fill(CGRect(x: 512 - stemWidth / 2, y: centre.y + radius - 10, width: stemWidth, height: 70))
    let crown = CGRect(x: 512 - stemWidth, y: centre.y + radius + 50, width: stemWidth * 2, height: tiny ? 56 : 52)
    ctx.addPath(CGPath(roundedRect: crown, cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.fillPath()
    if !tiny {
        ctx.saveGState()
        ctx.translateBy(x: centre.x, y: centre.y)
        ctx.rotate(by: -.pi / 4)
        ctx.addPath(
            CGPath(
                roundedRect: CGRect(x: -34, y: radius - 6, width: 68, height: 66), cornerWidth: 16, cornerHeight: 16,
                transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // Face with a dark rim.
    ctx.setFillColor(rim)
    ctx.fillEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
    let inner = radius - rimWidth
    ctx.setFillColor(face)
    ctx.fillEllipse(in: CGRect(x: centre.x - inner, y: centre.y - inner, width: inner * 2, height: inner * 2))

    // Elapsed time: a wedge from 12 o'clock clockwise to 4 o'clock.
    let wedgeRadius = inner - (tiny ? 0 : 18)
    let start = CGFloat.pi / 2
    let end = start - 2 * .pi * (4.0 / 12.0)
    ctx.move(to: centre)
    ctx.addArc(center: centre, radius: wedgeRadius, startAngle: start, endAngle: end, clockwise: true)
    ctx.closePath()
    ctx.setFillColor(elapsed)
    ctx.fillPath()

    // Tick marks at the twelve hours, longer at the quarters. Too fine to read below 64px.
    if px >= 64 {
        ctx.setStrokeColor(ink)
        ctx.setLineCap(.round)
        for hour in 0..<12 {
            let angle = CGFloat.pi / 2 - CGFloat(hour) * .pi / 6
            let major = hour % 3 == 0
            let outer = inner - 26
            let length: CGFloat = major ? 50 : 26
            ctx.setLineWidth(major ? 20 : 12)
            ctx.move(to: CGPoint(x: centre.x + cos(angle) * outer, y: centre.y + sin(angle) * outer))
            ctx.addLine(
                to: CGPoint(x: centre.x + cos(angle) * (outer - length), y: centre.y + sin(angle) * (outer - length)))
            ctx.strokePath()
        }
    }

    // One hand, at the end of the wedge, and a hub.
    ctx.setStrokeColor(ink)
    ctx.setLineCap(.round)
    ctx.setLineWidth(tiny ? 64 : (small ? 48 : 30))
    let handLength = inner - (tiny ? 40 : 70)
    ctx.move(to: centre)
    ctx.addLine(to: CGPoint(x: centre.x + cos(end) * handLength, y: centre.y + sin(end) * handLength))
    ctx.strokePath()
    let hub: CGFloat = tiny ? 50 : 40
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: CGRect(x: centre.x - hub, y: centre.y - hub, width: hub * 2, height: hub * 2))
}

func write(px: Int, name: String) throws {
    let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    draw(ctx, px: px)
    let url = outDir.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

// The ten files iconutil expects in an .iconset.
for points in [16, 32, 128, 256, 512] {
    try write(px: points, name: "icon_\(points)x\(points).png")
    try write(px: points * 2, name: "icon_\(points)x\(points)@2x.png")
}

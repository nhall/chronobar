// Renders Chronobar's app icon, design "G2": the Chronos symbol (an upper half-circle, a stem
// through its centre and a crossbar) in blue on a white disc, on a blue rounded-square tile.
// It needs only the Command Line Tools. The PNGs it writes are committed, and
// scripts/bundle-app.sh turns them into Chronobar.icns with `iconutil`.
//
// To regenerate the icon after changing this file:
//
//   swift scripts/make-icon.swift packaging/icon/AppIcon.iconset
//
// Each size is drawn directly at its pixel size rather than scaled down from 1024px. The
// symbol's stroke gets bolder at 32 and 16 pt (see `strokeWidth`) so it still reads there.
// Every number that shapes the design is in the constants below.

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

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, alpha])!
}

// Design constants, on a 1024-unit canvas with y running down.

// Tile: the macOS icon grid's 824-unit rounded square, with a vertical gradient.
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileCorner: CGFloat = 185
let tileTop = rgb(0.33, 0.58, 1.0)
let tileBottom = rgb(0.18, 0.42, 0.90)

// Disc.
let discCentre = CGPoint(x: 512, y: 512)
let discRadius: CGFloat = 340
let discColor = rgb(1, 1, 1)

// Symbol.
let ink = rgb(0.18, 0.42, 0.90)
let arcRadius: CGFloat = 150  // r, at the stroke's centre line
let arcCentreY = 512 - 0.525 * arcRadius  // cy: centres the symbol on its bounding box
let stemBottom = arcCentreY + 2.05 * arcRadius
let crossbarY = arcCentreY + 1.05 * arcRadius
let crossbarHalfLength = 0.5 * arcRadius

/// The symbol's stroke width at a point size: bolder as the icon shrinks.
func strokeWidth(points: Int) -> CGFloat {
    switch points {
    case ...16: return 64 * 1.65
    case ...32: return 64 * 1.3
    default: return 64
    }
}

/// Draws the icon at `points` into a square context `px` pixels wide.
func draw(_ ctx: CGContext, px: Int, points: Int) {
    let s = CGFloat(px) / 1024
    // Flip so the geometry above reads y down, as in the sketch.
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: s, y: -s)

    // Tile, with a soft drop shadow where there are pixels enough to show it.
    let tile = CGPath(roundedRect: tileRect, cornerWidth: tileCorner, cornerHeight: tileCorner, transform: nil)
    if px > 32 {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * s), blur: 24 * s, color: rgb(0, 0, 0, 0.35))
        ctx.addPath(tile)
        ctx.setFillColor(tileBottom)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: space, colors: [tileTop, tileBottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        gradient, start: CGPoint(x: 512, y: tileRect.minY), end: CGPoint(x: 512, y: tileRect.maxY), options: [])
    ctx.restoreGState()

    // Disc.
    ctx.setFillColor(discColor)
    ctx.fillEllipse(
        in: CGRect(
            x: discCentre.x - discRadius, y: discCentre.y - discRadius, width: discRadius * 2,
            height: discRadius * 2))

    // Chronos symbol, with butt caps.
    let w = strokeWidth(points: points)
    let cx: CGFloat = 512
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(w)
    ctx.setLineCap(.butt)

    // Upper half-circle: from the left end over the top to the right end (y down, so the
    // angle runs from π through 3π/2).
    ctx.move(to: CGPoint(x: cx - arcRadius, y: arcCentreY))
    ctx.addArc(
        center: CGPoint(x: cx, y: arcCentreY), radius: arcRadius, startAngle: .pi, endAngle: 2 * .pi,
        clockwise: false)
    ctx.strokePath()

    // Stem, from the arc's outer top edge down.
    ctx.move(to: CGPoint(x: cx, y: arcCentreY - arcRadius - w / 2))
    ctx.addLine(to: CGPoint(x: cx, y: stemBottom))
    ctx.strokePath()

    // Crossbar.
    ctx.move(to: CGPoint(x: cx - crossbarHalfLength, y: crossbarY))
    ctx.addLine(to: CGPoint(x: cx + crossbarHalfLength, y: crossbarY))
    ctx.strokePath()
}

func write(points: Int, scale: Int, name: String) throws {
    let px = points * scale
    let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.setShouldAntialias(true)
    draw(ctx, px: px, points: points)
    let url = outDir.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
}

// The ten files iconutil expects in an .iconset.
for points in [16, 32, 128, 256, 512] {
    try write(points: points, scale: 1, name: "icon_\(points)x\(points).png")
    try write(points: points, scale: 2, name: "icon_\(points)x\(points)@2x.png")
}

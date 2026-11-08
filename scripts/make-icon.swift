// Renders Chronobar's app icon: a deep-blue chronograph dial with a white rim, hour ticks and a
// 12 o'clock bar, and three solid white subdials at 9, 3 and 6 o'clock, each with a short blue
// hand, on a blue rounded-square tile. It needs only the Command Line Tools. The PNGs it writes
// are committed, and scripts/bundle-app.sh turns them into Chronobar.icns with `iconutil`.
//
// To regenerate the icon after changing this file:
//
//   swift scripts/make-icon.swift packaging/icon/AppIcon.iconset
//
// Each size is drawn directly at its pixel size rather than scaled down from 1024px. At 32 and
// 16 pt the dial and subdials grow, the rim, rings and hands get heavier (see `weight`) and the
// ticks go, so the icon still reads there. Every number that shapes the design is in the
// constants below.

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

// Dial, with a vertical gradient from 64 pt up and solid below.
let centre = CGPoint(x: 512, y: 512)
let dialRadius: CGFloat = 352
let smallDialRadius: CGFloat = 372
let dialTop = rgb(0.10, 0.27, 0.70)
let dialBottom = rgb(0.07, 0.20, 0.56)
let white = rgb(1, 1, 1)
let rimWidth: CGFloat = 12  // from 64 pt up, inside the dial's edge, slightly translucent
let rimColor = rgb(1, 1, 1, 0.85)
let smallRimWidth: CGFloat = 28  // at 32 pt and below, times `weight`

// Hour ticks and the 12 o'clock bar, from 64 pt up, both starting `tickInset` inside the dial's edge.
let tickInset: CGFloat = 26
let tickLength: CGFloat = 40
let tickWidth: CGFloat = 14
let barWidth: CGFloat = 28
let barLength: CGFloat = 70

// Subdials: white discs at 9, 3 and 6 o'clock, `subdialOffset` from the centre, with ink hands
// pointing to 10, 2 and 12 o'clock.
let ink = rgb(0.18, 0.42, 0.90)
let subdialOffset: CGFloat = 178
let subdialRadius: CGFloat = 108
let smallSubdialOffset: CGFloat = 182
let smallSubdialRadius: CGFloat = 124
let ringWidth: CGFloat = 26
let smallRingWidth: CGFloat = 34  // at 32 pt and below, times `weight`
let handWidth: CGFloat = 26
let smallHandWidth: CGFloat = 32  // at 32 pt and below, times `weight`
let handAngles: [CGFloat] = [300, 60, 0]  // degrees clockwise from 12, for the 9, 3 and 6 o'clock subdials

/// How much heavier the rim, rings and hands are at a point size.
func weight(points: Int) -> CGFloat {
    switch points {
    case ...16: return 1.65
    case ...32: return 1.3
    default: return 1
    }
}

func circle(_ c: CGPoint, _ r: CGFloat) -> CGRect {
    CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
}

func strokeCircle(_ ctx: CGContext, _ c: CGPoint, radius: CGFloat, width: CGFloat, _ color: CGColor) {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.strokeEllipse(in: circle(c, radius))
}

/// A point `distance` from `c` at `degrees` clockwise from 12 o'clock.
func point(from c: CGPoint, degrees: CGFloat, distance: CGFloat) -> CGPoint {
    let a = degrees * .pi / 180
    return CGPoint(x: c.x + sin(a) * distance, y: c.y - cos(a) * distance)
}

/// Draws the icon at `points` into a square context `px` pixels wide.
func draw(_ ctx: CGContext, px: Int, points: Int) {
    let s = CGFloat(px) / 1024
    let small = points <= 32
    let w = weight(points: points)
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

    // Dial, with its own soft shadow where there are pixels enough.
    let R = small ? smallDialRadius : dialRadius
    if px > 32 {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -8 * s), blur: 18 * s, color: rgb(0, 0, 0, 0.25))
        ctx.setFillColor(dialTop)
        ctx.fillEllipse(in: circle(centre, R))
        ctx.restoreGState()
    } else {
        ctx.setFillColor(dialTop)
        ctx.fillEllipse(in: circle(centre, R))
    }
    if small {
        strokeCircle(ctx, centre, radius: R - smallRimWidth * w / 2, width: smallRimWidth * w, white)
    } else {
        ctx.saveGState()
        ctx.addEllipse(in: circle(centre, R))
        ctx.clip()
        let dialGradient = CGGradient(
            colorsSpace: space, colors: [dialTop, dialBottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(
            dialGradient, start: CGPoint(x: 512, y: centre.y - R), end: CGPoint(x: 512, y: centre.y + R),
            options: [])
        ctx.restoreGState()
        strokeCircle(ctx, centre, radius: R - rimWidth / 2, width: rimWidth, rimColor)

        // Hour ticks, with butt caps, except at 3, 6 and 9 where the subdials sit; and the 12 o'clock
        // bar over the tick at 12.
        let tickOuter = R - tickInset
        ctx.setStrokeColor(white)
        ctx.setLineWidth(tickWidth)
        ctx.setLineCap(.butt)
        for hour in 0..<12 where ![3, 6, 9].contains(hour) {
            let degrees = CGFloat(hour) * 30
            ctx.move(to: point(from: centre, degrees: degrees, distance: tickOuter - tickLength))
            ctx.addLine(to: point(from: centre, degrees: degrees, distance: tickOuter))
        }
        ctx.strokePath()
        ctx.setFillColor(white)
        ctx.fill(CGRect(x: 512 - barWidth / 2, y: centre.y - tickOuter, width: barWidth, height: barLength))
    }

    // Subdials: a white disc with a white ring on its edge, which draws the antialiased edge twice
    // and so keeps it crisp at small sizes; and a hand with round caps (shorter at 16 pt).
    let offset = small ? smallSubdialOffset : subdialOffset
    let r = small ? smallSubdialRadius : subdialRadius
    let ring = (small ? smallRingWidth : ringWidth) * w
    let handLength = r * (points <= 16 ? 0.55 : 0.62)
    let subdials = [
        CGPoint(x: centre.x - offset, y: centre.y), CGPoint(x: centre.x + offset, y: centre.y),
        CGPoint(x: centre.x, y: centre.y + offset),
    ]
    for (c, angle) in zip(subdials, handAngles) {
        ctx.setFillColor(white)
        ctx.fillEllipse(in: circle(c, r))
        strokeCircle(ctx, c, radius: r - ring / 2, width: ring, white)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth((small ? smallHandWidth : handWidth) * w)
        ctx.setLineCap(.round)
        ctx.move(to: c)
        ctx.addLine(to: point(from: c, degrees: angle, distance: handLength))
        ctx.strokePath()
    }
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

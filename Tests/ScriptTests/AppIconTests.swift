import CoreGraphics
import Foundation
import ImageIO
import Testing

/// Runs scripts/make-icon.swift into a temporary iconset and checks the PNGs it writes.
///
/// Expected positions come from the chronograph dial's geometry, on a 1024 canvas with y down,
/// centred on (512, 512). From 64 pt up: dial radius 352 with a 12-unit rim on its edge; hour ticks
/// from radius 286 to 326; a 12 o'clock bar 28 wide from y 186 to 256; subdials of radius 108 at
/// 178 left, right and below the centre, each with a 26-wide hand 67 long, pointing to 10, 2 and 12.
/// At 32 pt and below: dial radius 372 with a white rim at least 36 wide, and no ticks.
@Suite struct AppIconTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// One render shared by every test; the script takes a few seconds to compile. A failed render fails
    /// each test that asks for it, rather than crashing the test run.
    private static let render = Result { () throws -> URL in
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScriptTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("AppIcon.iconset", isDirectory: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", repo.appendingPathComponent("scripts/make-icon.swift").path, out.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ScriptFailed(status: process.terminationStatus) }
        return out
    }

    private static func rendered(_ name: String) throws -> URL {
        try render.get().appendingPathComponent(name)
    }

    private static let ink = Pixel(r: 46, g: 107, b: 230)  // sRGB (0.18, 0.42, 0.90)
    private static let white = Pixel(r: 255, g: 255, b: 255)

    @Test func theLargestRenderDrawsAChronographDialWithThreeSubdials() throws {
        let icon = try Bitmap(Self.rendered("icon_512x512@2x.png"))
        try #require(icon.width == 1024 && icon.height == 1024)

        // Outside the tile: transparent.
        #expect(icon[20, 20].a == 0)
        // Tile, between its top edge (y 100) and the dial (y 160): the tile's blue.
        #expect(icon[512, 130].isTileBlue)
        // Dial: deep blue at the centre and between the ticks.
        #expect(icon[512, 512].isDeepBlue)
        #expect(icon[512, 400].isDeepBlue)
        // Rim, from radius 340 to 352: near white.
        #expect(icon[512, 166].r > 200)

        // 12 o'clock bar, x 498 to 526, y 186 to 256.
        #expect(icon[512, 240].isClose(to: Self.white))
        #expect(icon[532, 240].isDeepBlue)
        #expect(icon[512, 265].isDeepBlue)
        // An hour tick at 1 o'clock, and none at 3 o'clock, where the subdial sits.
        #expect(icon[665, 247].isClose(to: Self.white))
        #expect(icon[820, 512].isDeepBlue)

        // Subdials: solid white discs.
        #expect(icon[374, 552].isClose(to: Self.white))
        #expect(icon[730, 552].isClose(to: Self.white))
        #expect(icon[512, 760].isClose(to: Self.white))
        // Hands in ink: the 6 o'clock subdial's points up, the others to 10 and 2.
        #expect(icon[512, 650].isClose(to: Self.ink))
        #expect(icon[512, 720].isClose(to: Self.white))
        #expect(icon[305, 495].isClose(to: Self.ink))
        #expect(icon[719, 495].isClose(to: Self.ink))
    }

    /// At 32 pt and below the dial grows, its rim gets heavier and the hour ticks go, whatever the
    /// pixel size: a 32 pt @2x render is drawn differently from the 128 pt render of the same design.
    @Test func smallPointSizesDropTheTicksAndGrowTheDial() throws {
        let small = try Bitmap(Self.rendered("icon_32x32@2x.png"))  // 64 px, 16 units a pixel
        let large = try Bitmap(Self.rendered("icon_128x128@2x.png"))  // 256 px, 4 units a pixel
        // The 1 o'clock tick, at (665, 247).
        #expect(small[41, 15].isDeepBlue)
        #expect(large[166, 62].r > 200)
        // Radius 360 above the centre: white rim when small, the tile outside the dial when large.
        #expect(small[32, 9].isClose(to: Self.white))
        #expect(large[130, 38].isTileBlue)
    }

    /// 16 pt rims and hands are 1.65× and 32 pt ones 1.3× as heavy, so at the same pixel size the
    /// smaller point size is a bolder drawing rather than a scaled copy.
    @Test func smallPointSizesAreDrawnWithHeavierRims() throws {
        let file = { (name: String) in try Bitmap(Self.rendered(name)) }
        // Both 32 px.
        let at16pt = try file("icon_16x16@2x.png").whiteCoverage
        let at32pt = try file("icon_32x32.png").whiteCoverage
        #expect(at16pt / at32pt > 1.03)

        // From 128 pt up the drawing is the same, whatever the pixel size.
        let at128ptRetina = try file("icon_128x128@2x.png").whiteCoverage
        let at512ptRetina = try file("icon_512x512@2x.png").whiteCoverage
        #expect(abs(at128ptRetina / at512ptRetina - 1) < 0.03)
    }

    /// The bundle is built from packaging/icon/AppIcon.iconset, so it must draw what the generator draws:
    /// regenerate with `swift scripts/make-icon.swift packaging/icon/AppIcon.iconset`. Pixels are compared
    /// rather than bytes, so a PNG encoder that writes the same image differently doesn't fail this.
    @Test func theCommittedIconsetIsWhatTheGeneratorWrites() throws {
        let committed = Self.repo.appendingPathComponent("packaging/icon/AppIcon.iconset")
        let names = [16, 32, 128, 256, 512].flatMap { ["icon_\($0)x\($0).png", "icon_\($0)x\($0)@2x.png"] }
        let renderedFolder = try Self.render.get()
        #expect(try FileManager.default.contentsOfDirectory(atPath: renderedFolder.path).sorted() == names.sorted())
        #expect(try FileManager.default.contentsOfDirectory(atPath: committed.path).sorted() == names.sorted())
        for name in names {
            let fresh = try Bitmap(renderedFolder.appendingPathComponent(name))
            let stored = try Bitmap(committed.appendingPathComponent(name))
            #expect(fresh.isClose(to: stored), "\(name) is stale")
        }
    }
}

private struct ScriptFailed: Error, CustomStringConvertible {
    let status: Int32
    var description: String { "scripts/make-icon.swift exited with status \(status)" }
}

private struct Pixel {
    var r, g, b: Int
    var a = 255

    func isClose(to other: Pixel, tolerance: Int = 4) -> Bool {
        abs(r - other.r) <= tolerance && abs(g - other.g) <= tolerance && abs(b - other.b) <= tolerance
            && abs(a - other.a) <= tolerance
    }

    /// The tile's gradient, sRGB (0.33, 0.58, 1.0) to (0.18, 0.42, 0.90).
    var isTileBlue: Bool { (40...90).contains(r) && (100...155).contains(g) && b >= 225 && a == 255 }

    /// The dial's gradient, sRGB (0.10, 0.27, 0.70) to (0.07, 0.20, 0.56).
    var isDeepBlue: Bool { (15...30).contains(r) && (48...72).contains(g) && (138...182).contains(b) }
}

/// A PNG decoded to premultiplied RGBA8. The pixels the tests sample are opaque or fully clear,
/// so premultiplication doesn't change their colour.
private struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path]) }
        let (width, height) = (image.width, image.height)
        self.width = width
        self.height = height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path]) }
        self.bytes = bytes
    }

    /// The pixel at (x, y), y down from the top.
    subscript(x: Int, y: Int) -> Pixel {
        let i = (y * width + x) * 4
        return Pixel(r: Int(bytes[i]), g: Int(bytes[i + 1]), b: Int(bytes[i + 2]), a: Int(bytes[i + 3]))
    }

    /// The same size, with every channel of every pixel within `tolerance` of `other`'s.
    func isClose(to other: Bitmap, tolerance: Int = 1) -> Bool {
        width == other.width && height == other.height
            && zip(bytes, other.bytes).allSatisfy { abs(Int($0) - Int($1)) <= tolerance }
    }

    /// How much of the dial is white, from 0 to 1, read off the red channel (255 in white, 25 on the
    /// deep-blue dial). It covers radius 372, the largest dial; anything under 25 counts as none.
    var whiteCoverage: Double {
        let scale = Double(width) / 1024
        var white = 0.0
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let dx = (Double(x) + 0.5) / scale - 512
                let dy = (Double(y) + 0.5) / scale - 512
                guard dx * dx + dy * dy < 372 * 372 else { continue }
                white += max(0, Double(self[x, y].r - 25)) / Double(255 - 25)
                count += 1
            }
        }
        return white / Double(count)
    }
}

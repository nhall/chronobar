import CoreGraphics
import Foundation
import ImageIO
import Testing

/// Runs scripts/make-icon.swift into a temporary iconset and checks the PNGs it writes.
///
/// Expected positions come from the G2 geometry in issue #32, on a 1024 canvas with y down:
/// r = 150, w = 64, cy = 512 − 0.525·r = 433.25, so the arc's outer top is at y = 251.25,
/// the stem runs to y = 740.75 and the crossbar sits at y = 590.75 from x = 437 to 587.
@Suite struct AppIconTests {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// One render shared by every test; the script takes a few seconds to compile.
    static let rendered: URL = {
        let out = temporaryRoot().appendingPathComponent("AppIcon.iconset", isDirectory: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", repo.appendingPathComponent("scripts/make-icon.swift").path, out.path]
        try! process.run()
        process.waitUntilExit()
        precondition(process.terminationStatus == 0, "make-icon.swift failed")
        return out
    }()

    static let ink = Pixel(r: 46, g: 107, b: 230)  // sRGB (0.18, 0.42, 0.90)
    static let white = Pixel(r: 255, g: 255, b: 255)

    @Test func theLargestRenderDrawsTheChronosSymbolOnAWhiteDisc() throws {
        let icon = try Bitmap(Self.rendered.appendingPathComponent("icon_512x512@2x.png"))
        #expect(icon.width == 1024 && icon.height == 1024)

        // Outside the tile: transparent.
        #expect(icon[20, 20].a == 0)
        // Tile, between its top edge (y 100) and the disc (y 172): blue, not white.
        #expect(icon[512, 136].b > 200 && icon[512, 136].r < 120)
        // Disc: white just inside its edge and above the symbol.
        #expect(icon[200, 512].isClose(to: Self.white))
        #expect(icon[512, 230].isClose(to: Self.white))

        // Arc: its top, and its left end just above the arc centre line.
        #expect(icon[512, 262].isClose(to: Self.ink))
        #expect(icon[364, 425].isClose(to: Self.ink))
        // Butt caps: nothing below the arc's ends.
        #expect(icon[364, 445].isClose(to: Self.white))
        #expect(icon[660, 445].isClose(to: Self.white))
        // Stem, through the arc centre and down to y 740.75.
        #expect(icon[512, 433].isClose(to: Self.ink))
        #expect(icon[512, 735].isClose(to: Self.ink))
        #expect(icon[512, 750].isClose(to: Self.white))
        // Stroke width 64: the stem spans x 480 to 544.
        #expect(icon[485, 680].isClose(to: Self.ink))
        #expect(icon[475, 680].isClose(to: Self.white))
        // Crossbar at y 590.75 from x 437 to 587.
        #expect(icon[445, 591].isClose(to: Self.ink))
        #expect(icon[580, 591].isClose(to: Self.ink))
        #expect(icon[595, 591].isClose(to: Self.white))
        #expect(icon[560, 630].isClose(to: Self.white))
    }

    /// 16 pt strokes are 1.65× and 32 pt strokes 1.3× the 64-unit stroke used from 64 pt up, so
    /// at the same pixel size the smaller point size carries more ink rather than being a scaled copy.
    @Test func smallPointSizesAreDrawnWithBolderStrokes() throws {
        let file = { (name: String) in try Bitmap(Self.rendered.appendingPathComponent(name)) }
        // Each pair shares a pixel size but not a point size.
        let at16pt = try file("icon_16x16@2x.png").inkCoverage
        let at32pt = try file("icon_32x32.png").inkCoverage
        #expect(at16pt / at32pt > 1.15)

        let at32ptRetina = try file("icon_32x32@2x.png").inkCoverage
        let at128pt = try file("icon_128x128.png").inkCoverage
        #expect(at32ptRetina / at128pt > 1.15)

        // From 128 pt up the drawing is the same, whatever the pixel size.
        let at128ptRetina = try file("icon_128x128@2x.png").inkCoverage
        let at512ptRetina = try file("icon_512x512@2x.png").inkCoverage
        #expect(abs(at128ptRetina / at512ptRetina - 1) < 0.03)
    }

    /// The bundle is built from packaging/icon/AppIcon.iconset, so it must be exactly what the
    /// generator writes: regenerate with `swift scripts/make-icon.swift packaging/icon/AppIcon.iconset`.
    @Test func theCommittedIconsetIsWhatTheGeneratorWrites() throws {
        let committed = Self.repo.appendingPathComponent("packaging/icon/AppIcon.iconset")
        let names = [16, 32, 128, 256, 512].flatMap { ["icon_\($0)x\($0).png", "icon_\($0)x\($0)@2x.png"] }
        #expect(try FileManager.default.contentsOfDirectory(atPath: Self.rendered.path).sorted() == names.sorted())
        #expect(try FileManager.default.contentsOfDirectory(atPath: committed.path).sorted() == names.sorted())
        for name in names {
            let fresh = try Data(contentsOf: Self.rendered.appendingPathComponent(name))
            let stored = try Data(contentsOf: committed.appendingPathComponent(name))
            #expect(fresh == stored, "\(name) is stale")
        }
    }
}

struct Pixel {
    var r, g, b: Int
    var a = 255

    func isClose(to other: Pixel, tolerance: Int = 4) -> Bool {
        abs(r - other.r) <= tolerance && abs(g - other.g) <= tolerance && abs(b - other.b) <= tolerance
            && abs(a - other.a) <= tolerance
    }
}

/// A PNG decoded to premultiplied RGBA8. The pixels the tests sample are opaque or fully clear,
/// so premultiplication doesn't change their colour.
struct Bitmap {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ url: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw CocoaError(.fileReadCorruptFile) }
        width = image.width
        height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let ctx = CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    /// The pixel at (x, y), y down from the top.
    subscript(x: Int, y: Int) -> Pixel {
        let i = (y * width + x) * 4
        return Pixel(r: Int(bytes[i]), g: Int(bytes[i + 1]), b: Int(bytes[i + 2]), a: Int(bytes[i + 3]))
    }

    /// How much of the disc's middle is ink, from 0 (all white) to 1, read off the red channel
    /// (255 on the white disc, 46 in the ink). The middle, radius 300 of 340, holds the whole symbol.
    var inkCoverage: Double {
        let scale = Double(width) / 1024
        var ink = 0.0
        var count = 0
        for y in 0..<height {
            for x in 0..<width {
                let dx = (Double(x) + 0.5) / scale - 512
                let dy = (Double(y) + 0.5) / scale - 512
                guard dx * dx + dy * dy < 300 * 300 else { continue }
                ink += Double(255 - self[x, y].r) / Double(255 - 46)
                count += 1
            }
        }
        return ink / Double(count)
    }
}

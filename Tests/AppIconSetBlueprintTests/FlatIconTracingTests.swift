import BlueprintCore
import CoreGraphics
import Testing
@testable import AppIconSetBlueprint

/// Tests outlining the foreground of a flat icon image.
@Suite struct FlatIconTracingTests {

    // MARK: - Fixtures

    private let side = 256

    /// A dark square in the middle of a light background.
    private func flatIcon() throws -> RGBAImage {
        try RGBAImage(width: side, height: side) { context in
            context.setFillColor(gray: 0.9, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.setFillColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)
            context.fill(CGRect(x: 64, y: 64, width: 128, height: 128))
        }
    }

    /// A silhouette finder that always returns the same mask, standing in for Vision.
    private struct FixedSilhouette: SilhouetteFinder {
        let mask: AlphaMask
        func silhouette(of icon: RGBAImage) throws -> AlphaMask { mask }
    }

    /// A soft-edged square, like Vision's scaled-up mask.
    private func softSquare(from start: Int, to end: Int) -> AlphaMask {
        AlphaMask(width: side, height: side) { x, y in
            let inside = (start..<end).contains(x) && (start..<end).contains(y)
            let onEdge = x == start || y == start || x == end - 1 || y == end - 1
            return inside ? (onEdge ? 0.6 : 1) : 0
        }
    }

    private func value(of mask: AlphaMask, x: Int, y: Int) -> UInt8 {
        mask.pixels[y * mask.width + x]
    }

    // MARK: - Line Art

    @Test func outlinesTheForegroundAndLeavesTheBackgroundEmpty() throws {
        let foreground = FixedSilhouette(mask: softSquare(from: 64, to: 192))
        let tracer = FlatIconTracer(lineWidth: 6, silhouetteFinder: foreground)

        let lineArt = try tracer.lineArt(of: flatIcon())

        let onTheEdge = value(of: lineArt, x: 66, y: 128)
        let inTheMiddle = value(of: lineArt, x: 128, y: 128)
        let inTheBackground = value(of: lineArt, x: 10, y: 10)
        #expect(onTheEdge > 200)
        #expect(inTheMiddle < 50)
        #expect(inTheBackground == 0)
    }

    @Test func firmsUpTheSoftEdgeOfTheMask() throws {
        let foreground = FixedSilhouette(mask: softSquare(from: 64, to: 192))
        let tracer = FlatIconTracer(lineWidth: 6, silhouetteFinder: foreground)

        let lineArt = try tracer.lineArt(of: flatIcon())

        #expect(value(of: lineArt, x: 64, y: 128) == 255)
    }

    @Test func iconWithoutForegroundIsAnError() throws {
        let nothing = FixedSilhouette(mask: softSquare(from: 0, to: 0))
        let tracer = FlatIconTracer(lineWidth: 6, silhouetteFinder: nothing)

        #expect(throws: BlueprintError.noForeground) {
            try tracer.lineArt(of: self.flatIcon())
        }
    }
}

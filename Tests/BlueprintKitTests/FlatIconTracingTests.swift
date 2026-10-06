import CoreGraphics
import Testing
@testable import BlueprintKit

/// Tests finding the shapes in a flat icon image.
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

    private func value(of mask: AlphaMask, x: Int, y: Int) -> UInt8 {
        mask.pixels[y * mask.width + x]
    }

    /// A silhouette finder that always returns the same mask.
    private struct FixedSilhouette: SilhouetteFinder {
        let mask: AlphaMask
        func silhouette(of icon: RGBAImage) throws -> AlphaMask { mask }
    }

    private func square(from start: Int, to end: Int) -> AlphaMask {
        AlphaMask(width: side, height: side) { x, y in
            (start..<end).contains(x) && (start..<end).contains(y) ? 1 : 0
        }
    }

    // MARK: - Background Color

    @Test func backgroundColorFindsTheShape() throws {
        let silhouette = try BackgroundColorSilhouette().silhouette(of: flatIcon())

        #expect(value(of: silhouette, x: 128, y: 128) > 200)
        #expect(value(of: silhouette, x: 10, y: 10) < 50)
    }

    // MARK: - Choosing a Silhouette

    @Test func trustsTheBackgroundColorWhenVisionAgrees() throws {
        let backgroundShape = square(from: 64, to: 192)
        let similarSubject = square(from: 70, to: 192)
        let finder = BestSilhouette(byBackgroundColor: FixedSilhouette(mask: backgroundShape), bySubject: FixedSilhouette(mask: similarSubject))

        let silhouette = try finder.silhouette(of: flatIcon())

        #expect(silhouette.pixels == backgroundShape.pixels)
    }

    @Test func trustsVisionWhenTheBackgroundIsBusy() throws {
        let backgroundWithTexture = square(from: 0, to: 256)
        let subject = square(from: 64, to: 192)
        let finder = BestSilhouette(byBackgroundColor: FixedSilhouette(mask: backgroundWithTexture), bySubject: FixedSilhouette(mask: subject))

        let silhouette = try finder.silhouette(of: flatIcon())

        #expect(silhouette.pixels == subject.pixels)
    }

    @Test func fallsBackToTheBackgroundColorWhenVisionFindsNothing() throws {
        let backgroundShape = square(from: 64, to: 192)
        let nothing = square(from: 0, to: 0)
        let finder = BestSilhouette(byBackgroundColor: FixedSilhouette(mask: backgroundShape), bySubject: FixedSilhouette(mask: nothing))

        let silhouette = try finder.silhouette(of: flatIcon())

        #expect(silhouette.pixels == backgroundShape.pixels)
    }

    // MARK: - Line Art

    @Test func lineArtOutlinesTheShapeAndLeavesTheBackgroundEmpty() throws {
        let tracer = FlatIconTracer(lineWidth: 6, silhouetteFinder: BackgroundColorSilhouette())

        let lineArt = try tracer.lineArt(of: flatIcon())

        let onTheEdge = value(of: lineArt, x: 66, y: 128)
        let inTheMiddle = value(of: lineArt, x: 128, y: 128)
        let inTheBackground = value(of: lineArt, x: 10, y: 10)
        #expect(onTheEdge > 200)
        #expect(inTheMiddle < 50)
        #expect(inTheBackground == 0)
    }
}

import AppKit
import BlueprintCore
import BlueprintTestSupport
import Foundation
import ImageIO
import Testing
@testable import AppIconSetBlueprint

/// Tests drawing `.appiconset` blueprints to disk and recognizing them.
@Suite final class AppIconSetFormatTests {

    // MARK: - Fixtures

    private let format = AppIconSetFormat()
    private let catalog = Fixtures.temporaryFolder(named: "xcassets")
    private lazy var source = catalog.appendingPathComponent("AppIcon.appiconset")
    private lazy var destination = catalog.appendingPathComponent("AppIconDebug.appiconset")

    deinit {
        try? FileManager.default.removeItem(at: catalog)
    }

    private func drawBlueprint(style: BlueprintStyle? = nil) throws {
        let style = try style ?? BlueprintStyle()
        let blueprint = try format.blueprint(of: source, style: style)
        try blueprint.write(to: destination)
    }

    /// The red, green, blue and alpha of a pixel of the 1024 × 1024 blueprint, counted from the top left.
    private func blueprintPixel(x: Int, y: Int) throws -> [UInt8] {
        let imageURL = destination.appendingPathComponent("Blueprint 1024.png")
        let image = try #require(NSImage(contentsOf: imageURL))
        let picture = try RGBAImage(drawing: image, width: 1024, height: 1024)
        let start = (y * picture.width + x) * 4
        return Array(picture.bytes[start..<start + 4])
    }

    private func blueprintFileNames() throws -> Set<String> {
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        return Set(fileNames)
    }

    // MARK: - Drawing

    @Test func keepsEverySlotIncludingDarkAndTinted() throws {
        let slots = [Fixtures.iosSlot(), Fixtures.iosSlot(appearance: "dark"), Fixtures.iosSlot(appearance: "tinted")]
        try Fixtures.writeIconSet(at: source, slots: slots)

        try drawBlueprint()

        let contents = try AppIconSetContents.reading(destination)
        #expect(contents.images.count == 3)
        #expect(contents.images.allSatisfy { $0.filename == "Blueprint 1024.png" })
        #expect(contents.images.compactMap(\.appearances?.first?.value) == ["dark", "tinted"])
        #expect(try blueprintFileNames() == ["Blueprint 1024.png", "Contents.json"])
    }

    @Test func writesEverySizeOfAMacIconSet() throws {
        let sizes = [16, 32, 128, 256, 512]
        let slots = sizes.flatMap { points in
            ["1x", "2x"].map { scale in
                AppIconSetContents.Slot(filename: "Icon.png", idiom: "mac", size: "\(points)x\(points)", scale: scale)
            }
        }
        try Fixtures.writeIconSet(at: source, slots: slots, imageSide: 512)

        try drawBlueprint()

        let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]
        let expectedFiles = pixelSizes.map { "Blueprint \($0).png" } + ["Contents.json"]
        #expect(try blueprintFileNames() == Set(expectedFiles))
    }

    @Test func blueprintIsFullIconSize() throws {
        try Fixtures.writeIconSet(at: source, slots: [Fixtures.iosSlot()], imageSide: 512)

        try drawBlueprint()

        let imageURL = destination.appendingPathComponent("Blueprint 1024.png")
        let imageSource = try #require(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(image.width == 1024 && image.height == 1024)
    }

    @Test func badgeIsDrawnInTheBottomRightCorner() throws {
        try Fixtures.writeIconSet(at: source, slots: [Fixtures.iosSlot()])
        let besideTheBadgeText = (x: 920, y: 772)

        try drawBlueprint()
        let withoutBadge = try blueprintPixel(x: besideTheBadgeText.x, y: besideTheBadgeText.y)
        try drawBlueprint(style: BlueprintStyle(badge: BlueprintBadge(text: "DEV")))
        let withBadge = try blueprintPixel(x: besideTheBadgeText.x, y: besideTheBadgeText.y)

        #expect(withoutBadge != [255, 255, 255, 255])
        #expect(withBadge == [255, 255, 255, 255])
    }

    @Test func iconSetWithoutImagesIsAnError() throws {
        let emptySlot = AppIconSetContents.Slot(idiom: "universal", platform: "ios", size: "1024x1024")
        try Fixtures.writeIconSet(at: source, slots: [emptySlot])

        #expect(throws: BlueprintError.emptyIconSet("AppIcon.appiconset")) {
            try self.drawBlueprint()
        }
    }

    // MARK: - Recognizing

    @Test func recognizesItsOwnBlueprints() throws {
        try Fixtures.writeIconSet(at: source, slots: [Fixtures.iosSlot()])
        try drawBlueprint()

        #expect(format.isBlueprint(destination))
        #expect(!format.isBlueprint(source))
    }

    // MARK: - Slots

    @Test func slotPixelSizeIsPointsTimesScale() {
        let iPadPro = AppIconSetContents.Slot(size: "83.5x83.5", scale: "2x")
        let universal = AppIconSetContents.Slot(size: "1024x1024")

        #expect(iPadPro.pixelSize == 167)
        #expect(universal.pixelSize == 1024)
    }
}

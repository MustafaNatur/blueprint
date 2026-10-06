import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BlueprintKit

/// Tests drawing blueprints of asset catalog `.appiconset` folders.
@Suite final class AppIconSetTests {

    // MARK: - Fixtures

    private let catalog = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).xcassets")
    private lazy var source = catalog.appendingPathComponent("AppIcon.appiconset")
    private lazy var destination = catalog.appendingPathComponent("AppIconDebug.appiconset")

    deinit {
        try? FileManager.default.removeItem(at: catalog)
    }

    /// A flat icon: a dark square on a light gray background.
    private func flatIconPNG(side: Int = 1024) throws -> Data {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = try #require(CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(gray: 0.9, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.setFillColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)
        let squareSide = side / 2
        context.fill(CGRect(x: side / 4, y: side / 4, width: squareSide, height: squareSide))

        let png = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil))
        let image = try #require(context.makeImage())
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return png as Data
    }

    private func writeIconSet(slots: [AppIconSetContents.Slot], imageSide: Int = 1024) throws {
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let image = try flatIconPNG(side: imageSide)
        for fileName in Set(slots.compactMap(\.filename)) {
            try image.write(to: source.appendingPathComponent(fileName))
        }
        let info = AppIconSetContents.Info(author: "xcode", version: 1)
        let contents = AppIconSetContents(images: slots, info: info)
        try contents.write(to: source)
    }

    private func iosSlot(appearance: String? = nil) -> AppIconSetContents.Slot {
        let appearances = appearance.map { [AppIconSetContents.Appearance(appearance: "luminosity", value: $0)] }
        return AppIconSetContents.Slot(filename: "Icon.png", idiom: "universal", platform: "ios", size: "1024x1024", appearances: appearances)
    }

    private func blueprintFileNames() throws -> Set<String> {
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: destination.path)
        return Set(fileNames)
    }

    // MARK: - Drawing

    @Test func keepsEverySlotIncludingDarkAndTinted() throws {
        try writeIconSet(slots: [iosSlot(), iosSlot(appearance: "dark"), iosSlot(appearance: "tinted")])

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

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
        try writeIconSet(slots: slots, imageSide: 512)

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let pixelSizes = [16, 32, 64, 128, 256, 512, 1024]
        let expectedFiles = pixelSizes.map { "Blueprint \($0).png" } + ["Contents.json"]
        #expect(try blueprintFileNames() == Set(expectedFiles))
    }

    @Test func blueprintIsFullIconSize() throws {
        try writeIconSet(slots: [iosSlot()], imageSide: 512)

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let imageURL = destination.appendingPathComponent("Blueprint 1024.png")
        let imageSource = try #require(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil))
        #expect(image.width == 1024 && image.height == 1024)
    }

    @Test func iconSetWithoutImagesIsAnError() throws {
        let emptySlot = AppIconSetContents.Slot(idiom: "universal", platform: "ios", size: "1024x1024")
        try writeIconSet(slots: [emptySlot])

        #expect(throws: BlueprintError.emptyIconSet("AppIcon.appiconset")) {
            try BlueprintIcon.generate(from: self.source, to: self.destination, style: BlueprintStyle())
        }
    }

    // MARK: - Recognizing and Replacing

    @Test func recognizesItsOwnBlueprints() throws {
        try writeIconSet(slots: [iosSlot()])
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        #expect(BlueprintIcon.isBlueprint(destination))
        #expect(!BlueprintIcon.isBlueprint(source))
    }

    @Test func refusesToRedrawABlueprint() throws {
        try writeIconSet(slots: [iosSlot()])
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        let blueprint = destination
        let blueprintOfBlueprint = catalog.appendingPathComponent("AppIconDebugDebug.appiconset")

        #expect(throws: BlueprintError.alreadyBlueprint("AppIconDebug.appiconset")) {
            try BlueprintIcon.generate(from: blueprint, to: blueprintOfBlueprint, style: BlueprintStyle())
        }
    }

    @Test func refusesADestinationInAnotherFormat() throws {
        try writeIconSet(slots: [iosSlot()])
        let iconFile = catalog.appendingPathComponent("AppIconDebug.icon")

        #expect(throws: BlueprintError.formatMismatch("AppIcon.appiconset", "AppIconDebug.icon")) {
            try BlueprintIcon.generate(from: self.source, to: iconFile, style: BlueprintStyle())
        }
    }

    @Test func refusesOtherFiles() throws {
        let picture = catalog.appendingPathComponent("Logo.png")

        #expect(throws: BlueprintError.unsupportedFormat("Logo.png")) {
            try BlueprintIcon.generate(from: picture, to: self.destination, style: BlueprintStyle())
        }
    }

    // MARK: - Slots

    @Test func slotPixelSizeIsPointsTimesScale() {
        let iPadPro = AppIconSetContents.Slot(size: "83.5x83.5", scale: "2x")
        let universal = AppIconSetContents.Slot(size: "1024x1024")

        #expect(iPadPro.pixelSize == 167)
        #expect(universal.pixelSize == 1024)
    }
}

import CoreGraphics
import Foundation
import IconKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BlueprintKit

/// Tests drawing blueprints to disk and recognizing them.
@Suite final class BlueprintIconTests {

    // MARK: - Fixtures

    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    private lazy var destination = folder.appendingPathComponent("AppDebug.icon")

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    /// A PNG with a filled square inset from its edges.
    private func squarePNG(width: Int = 200, height: Int = 200, dpi: Double = 72) throws -> Data {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 20, y: 20, width: width - 40, height: height - 40))

        let png = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil))
        let resolution = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        let image = try #require(context.makeImage())
        CGImageDestinationAddImage(destination, image, resolution)
        CGImageDestinationFinalize(destination)
        return png as Data
    }

    /// Writes a one-layer icon to the test folder.
    private func writeIcon(named name: String = "App.icon", image: Data, imageName: String = "Layer.png") throws -> URL {
        let url = folder.appendingPathComponent(name)
        let layer = IconLayer(imageName: imageName)
        let document = IconDocument(groups: [IconGroup(layers: [layer])])
        let icon = IconComposerDescriptorFile(document: document, assets: [imageName: image])
        try icon.write(to: url)
        return url
    }

    private func assetFileNames(in bundle: URL) throws -> Set<String> {
        let assetsURL = IconBundle.assetsURL(in: bundle)
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: assetsURL.path)
        return Set(fileNames)
    }

    // MARK: - Drawing

    @Test func bitmapLayersKeepTheirPixelSize() throws {
        let image = try squarePNG(width: 400, height: 300, dpi: 144)
        let source = try writeIcon(image: image)

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let outlineURL = IconBundle.assetsURL(in: destination).appendingPathComponent("Layer.svg")
        let outline = try String(contentsOf: outlineURL, encoding: .utf8)
        #expect(outline.hasPrefix("<svg width='400' height='300'"))
    }

    @Test func layersKeepTheirColorsInDarkAndTintedIcons() throws {
        let source = try writeIcon(image: squarePNG())

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let descriptorURL = IconBundle.descriptorURL(in: destination)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let descriptor = try #require(try JSONSerialization.jsonObject(with: descriptorData) as? JSONObject)
        let groups = try #require(descriptor["groups"] as? [JSONObject])
        let layers = groups.flatMap { $0["layers"] as? [JSONObject] ?? [] }
        let drawingLayerAndGridAndBackground = 3
        #expect(layers.count == drawingLayerAndGridAndBackground)
        #expect(layers.allSatisfy { $0["fill"] as? String == "none" })
    }

    @Test func layerNamedLikeThePaperKeepsItsOutline() throws {
        let source = try writeIcon(image: squarePNG(), imageName: "background.png")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        #expect(try assetFileNames(in: destination) == ["Background.svg", "Grid.svg", "background 2.svg"])
    }

    @Test func leavesNoTemporaryFilesBehind() throws {
        let source = try writeIcon(image: squarePNG())

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let filesInFolder = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(filesInFolder.sorted() == ["App.icon", "AppDebug.icon"])
    }

    // MARK: - Replacing

    @Test func replacesABlueprintItDrewBefore() throws {
        let source = try writeIcon(image: squarePNG())

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle(showsGrid: false))

        #expect(try assetFileNames(in: destination) == ["Background.svg", "Layer.svg"])
    }

    @Test func refusesToOverwriteAnotherIcon() throws {
        let source = try writeIcon(image: squarePNG())
        let otherIcon = try writeIcon(named: "Other.icon", image: squarePNG())

        #expect(throws: BlueprintError.wouldOverwriteIcon("Other.icon")) {
            try BlueprintIcon.generate(from: source, to: otherIcon, style: BlueprintStyle())
        }
        #expect(try assetFileNames(in: otherIcon) == ["Layer.png"])
    }

    @Test func refusesToRedrawABlueprint() throws {
        let source = try writeIcon(image: squarePNG())
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        let blueprint = destination

        let blueprintOfBlueprint = folder.appendingPathComponent("AppDebugDebug.icon")

        #expect(throws: BlueprintError.alreadyBlueprint("AppDebug.icon")) {
            try BlueprintIcon.generate(from: blueprint, to: blueprintOfBlueprint, style: BlueprintStyle())
        }
    }

    // MARK: - Recognizing

    @Test func recognizesItsOwnBlueprints() throws {
        let source = try writeIcon(image: squarePNG())
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        #expect(BlueprintIcon.isBlueprint(destination))
        #expect(!BlueprintIcon.isBlueprint(source))
    }

    @Test func recognizesVersion1Blueprints() throws {
        let emptySVG = Data("<svg/>".utf8)
        let version1Blueprint = try writeIcon(named: "Old.icon", image: emptySVG, imageName: "Blueprint Paper.svg")
        #expect(BlueprintIcon.isBlueprint(version1Blueprint))
    }
}

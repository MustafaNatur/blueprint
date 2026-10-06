import BlueprintCore
import BlueprintTestSupport
import Foundation
import Testing
@testable import IconComposerBlueprint

/// Tests drawing `.icon` blueprints to disk and recognizing them.
@Suite final class IconComposerFormatTests {

    // MARK: - Fixtures

    private let format = IconComposerFormat()
    private let folder = Fixtures.temporaryFolder()
    private lazy var source = folder.appendingPathComponent("App.icon")
    private lazy var destination = folder.appendingPathComponent("AppDebug.icon")

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func drawBlueprint(style: BlueprintStyle? = nil) throws {
        let style = try style ?? BlueprintStyle()
        let blueprint = try format.blueprint(of: source, style: style)
        try blueprint.write(to: destination)
    }

    private func assetFileNames(in bundle: URL) throws -> Set<String> {
        let assetsURL = IconBundle.assetsURL(in: bundle)
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: assetsURL.path)
        return Set(fileNames)
    }

    // MARK: - Drawing

    @Test func countsTheOriginalLayers() throws {
        try Fixtures.writeIcon(at: source, image: Fixtures.layerPNG())

        let blueprint = try format.blueprint(of: source, style: BlueprintStyle())

        #expect(blueprint.layerCount == 1)
    }

    @Test func bitmapLayersKeepTheirPixelSize() throws {
        let image = try Fixtures.layerPNG(width: 400, height: 300, dpi: 144)
        try Fixtures.writeIcon(at: source, image: image)

        try drawBlueprint()

        let outlineURL = IconBundle.assetsURL(in: destination).appendingPathComponent("Layer.svg")
        let outline = try String(contentsOf: outlineURL, encoding: .utf8)
        #expect(outline.hasPrefix("<svg width='400' height='300'"))
    }

    @Test func layersKeepTheirColorsInDarkAndTintedIcons() throws {
        try Fixtures.writeIcon(at: source, image: Fixtures.layerPNG())

        try drawBlueprint()

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
        try Fixtures.writeIcon(at: source, image: Fixtures.layerPNG(), imageName: "background.png")

        try drawBlueprint()

        #expect(try assetFileNames(in: destination) == ["Background.svg", "Grid.svg", "background 2.svg"])
    }

    @Test func withoutGridThereIsNoGridFile() throws {
        try Fixtures.writeIcon(at: source, image: Fixtures.layerPNG())

        try drawBlueprint(style: BlueprintStyle(showsGrid: false))

        #expect(try assetFileNames(in: destination) == ["Background.svg", "Layer.svg"])
    }

    // MARK: - Recognizing

    @Test func recognizesItsOwnBlueprints() throws {
        try Fixtures.writeIcon(at: source, image: Fixtures.layerPNG())
        try drawBlueprint()

        #expect(format.isBlueprint(destination))
        #expect(!format.isBlueprint(source))
    }

    @Test func recognizesVersion1Blueprints() throws {
        let emptySVG = Data("<svg/>".utf8)
        let version1Blueprint = folder.appendingPathComponent("Old.icon")
        try Fixtures.writeIcon(at: version1Blueprint, image: emptySVG, imageName: "Blueprint Paper.svg")

        #expect(format.isBlueprint(version1Blueprint))
    }
}

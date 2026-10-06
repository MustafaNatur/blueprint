import CoreGraphics
import Foundation
import IconKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import BlueprintKit

@Suite struct BlueprintFileTests {
    private let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    private func png(width: Int, height: Int, dpi: Double) throws -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(red: 1, green: 0, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 20, y: 20, width: width - 40, height: height - 40))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, [
            kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi,
        ] as CFDictionary)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func writeIcon(named name: String, layer: Data, imageName: String = "Layer.png") throws -> URL {
        let url = folder.appendingPathComponent(name)
        let document = IconDocument(groups: [IconGroup(layers: [IconLayer(imageName: imageName)])])
        try IconComposerDescriptorFile(document: document, assets: [imageName: layer]).write(to: url)
        return url
    }

    @Test func bitmapLayersKeepTheirPixelSize() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try writeIcon(named: "App.icon", layer: png(width: 400, height: 300, dpi: 144))
        let destination = folder.appendingPathComponent("AppDebug.icon")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let svg = try String(contentsOf: destination.appendingPathComponent("Assets/Layer.svg"), encoding: .utf8)
        #expect(svg.hasPrefix(#"<svg width="400" height="300""#))
    }

    @Test func replacesOldBlueprintsButNotOtherIcons() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let layer = try png(width: 200, height: 200, dpi: 72)
        let source = try writeIcon(named: "App.icon", layer: layer)
        let destination = folder.appendingPathComponent("AppDebug.icon")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        #expect(BlueprintIcon.isBlueprint(destination))

        let handMade = try writeIcon(named: "Other.icon", layer: layer)
        #expect(throws: BlueprintError.self) {
            try BlueprintIcon.generate(from: source, to: handMade, style: BlueprintStyle())
        }
        #expect(!BlueprintIcon.isBlueprint(handMade))
    }

    @Test func refusesToRedrawABlueprint() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try writeIcon(named: "App.icon", layer: png(width: 200, height: 200, dpi: 72))
        let blueprint = folder.appendingPathComponent("AppDebug.icon")
        try BlueprintIcon.generate(from: source, to: blueprint, style: BlueprintStyle())

        #expect(throws: BlueprintError.self) {
            try BlueprintIcon.generate(from: blueprint, to: folder.appendingPathComponent("AppDebugDebug.icon"), style: BlueprintStyle())
        }
    }

    @Test func layerNamedLikeThePaperKeepsItsOutline() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = try writeIcon(named: "App.icon", layer: png(width: 200, height: 200, dpi: 72), imageName: "background.png")
        let destination = folder.appendingPathComponent("AppDebug.icon")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        let assets = try FileManager.default.contentsOfDirectory(atPath: destination.appendingPathComponent("Assets").path)
        #expect(Set(assets) == ["Background.svg", "Grid.svg", "background 2.svg"])
    }
}

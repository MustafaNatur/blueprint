import Foundation
import IconKit
import Testing
@testable import BlueprintKit

@Suite struct BlueprintIconTests {
    private let card = Data("""
    <svg width="600" height="500" viewBox="0 0 600 500" xmlns="http://www.w3.org/2000/svg">
    <rect width="600" height="500" rx="138" fill="#f0a"/>
    </svg>
    """.utf8)

    private func icon() -> IconComposerDescriptorFile {
        let layer = IconLayer(
            name: "Card",
            imageName: "Card.svg",
            opacity: 0.85,
            glass: true,
            position: IconPosition(scale: 0.9, translationInPoints: [108, -168])
        )
        let group = IconGroup(layers: [layer], shadow: .neutral, translucency: .default)
        return IconComposerDescriptorFile(
            document: IconDocument(fill: .solid(IconColor(colorSpace: .gray, components: [0.9, 1])), groups: [group]),
            assets: ["Card.svg": card]
        )
    }

    @Test func keepsLayoutButFlattensMaterials() throws {
        let style = try BlueprintStyle()
        let blueprint = try icon().blueprint(style: style)
        let card = try #require(blueprint.document.groups.first?.layers.first)

        #expect(blueprint.document.fill == .solid(try parseHexIconColor("#10A3FA")))
        #expect(card.position == IconPosition(scale: 0.9, translationInPoints: [108, -168]))
        #expect(card.glass == false)
        #expect(card.opacity == nil)
        #expect(card.imageName == "Blueprint Card.svg")
        #expect(blueprint.document.groups.first?.shadow?.kind == IconShadow.Kind.none)
        #expect(blueprint.validateAssets().isEmpty)
    }

    @Test func paperSitsBehindEverything() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        #expect(blueprint.document.groups.count == 2)
        #expect(blueprint.document.groups.last?.layers.first?.imageName == IconComposerDescriptorFile.paperAssetName)
    }

    @Test func noGridKeepsTheGradient() throws {
        let paper = try #require(try icon().blueprint(style: BlueprintStyle(showsGrid: false)).assets[IconComposerDescriptorFile.paperAssetName])
        let svg = String(decoding: paper, as: UTF8.self)
        #expect(svg.contains("#0AC2FC") && svg.contains("#1A6FFB"))
        #expect(!svg.contains("<line "))
    }

    @Test func readsIconComposerNoneFills() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).icon")
        defer { try? FileManager.default.removeItem(at: bundle) }
        try icon().write(to: bundle)

        let jsonURL = bundle.appendingPathComponent("icon.json")
        let json = try String(contentsOf: jsonURL, encoding: .utf8)
            .replacingOccurrences(of: #""glass" : true"#, with: #""fill" : "none", "glass" : true"#)
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) { try IconComposerDescriptorFile(contentsOf: bundle) }
        let read = try IconComposerDescriptorFile.reading(bundle)
        #expect(read.document.groups.first?.layers.first?.fill == nil)
    }

    @Test func readsIconComposerLayerColorShadows() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).icon")
        defer { try? FileManager.default.removeItem(at: bundle) }
        try icon().write(to: bundle)

        let jsonURL = bundle.appendingPathComponent("icon.json")
        let json = try String(contentsOf: jsonURL, encoding: .utf8)
            .replacingOccurrences(of: #""kind" : "neutral""#, with: #""kind" : "layer-color""#)
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        #expect(throws: (any Error).self) { try IconComposerDescriptorFile(contentsOf: bundle) }
        let read = try IconComposerDescriptorFile.reading(bundle)
        #expect(read.document.groups.first?.layers.first?.position?.translationInPoints == [108, -168])
    }
}

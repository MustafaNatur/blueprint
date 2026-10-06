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
        #expect(card.name == "Card")
        #expect(card.imageName == "Card.svg")
        #expect(blueprint.document.groups.first?.shadow?.kind == IconShadow.Kind.none)
        #expect(blueprint.validateAssets().isEmpty)
    }

    @Test func namesGroupsAndLayersForIconComposer() throws {
        let groups = try icon().blueprint(style: BlueprintStyle()).document.groups
        #expect(groups.map(\.name) == ["Drawing", "Blueprint Paper"])
        #expect(groups[0].layers.map(\.name) == ["Card"])
        #expect(groups[1].layers.map(\.name) == ["Grid", "Background"])
        #expect(groups[1].layers.map(\.imageName) == ["Grid.svg", "Background.svg"])
    }

    @Test func noGridKeepsTheBackground() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle(showsGrid: false))
        #expect(blueprint.document.groups.last?.layers.map(\.name) == ["Background"])
        #expect(blueprint.assets["Grid.svg"] == nil)
        let background = String(decoding: try #require(blueprint.assets["Background.svg"]), as: UTF8.self)
        #expect(background.contains("#0AC2FC") && background.contains("#1A6FFB"))
    }

    @Test func keepsFileNamesUniqueAndClearOfThePaper() throws {
        var icon = icon()
        icon.document.groups[0].layers = [
            IconLayer(name: "Background", imageName: "Card.svg"),
            IconLayer(name: "Background", imageName: "Other.svg"),
        ]
        icon.assets["Other.svg"] = icon.assets["Card.svg"]
        let names = Set(try icon.blueprint(style: BlueprintStyle()).assets.keys)
        #expect(names == ["Background 2.svg", "Background 3.svg", "Grid.svg", "Background.svg"])
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

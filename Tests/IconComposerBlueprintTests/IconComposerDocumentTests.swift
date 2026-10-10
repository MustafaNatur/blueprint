import BlueprintCore
import Foundation
import IconKit
import Testing
@testable import IconComposerBlueprint

/// Tests turning an icon into a blueprint in memory.
@Suite struct IconComposerDocumentTests {

    // MARK: - Fixtures

    private let cardImage = Data("""
    <svg width="600" height="500" viewBox="0 0 600 500" xmlns="http://www.w3.org/2000/svg">
    <rect width="600" height="500" rx="138" fill="#f0a"/>
    </svg>
    """.utf8)

    private let cardPosition = IconPosition(scale: 0.9, translationInPoints: [108, -168])

    private func icon() -> IconComposerDescriptorFile {
        let card = IconLayer(name: "Card", imageName: "Card.svg", opacity: 0.85, glass: true, position: cardPosition)
        let group = IconGroup(layers: [card], shadow: .neutral, translucency: .default)
        return IconComposerDescriptorFile(
            document: IconDocument(fill: .solid(IconColor(colorSpace: .gray, components: [0.9, 1])), groups: [group]),
            assets: ["Card.svg": cardImage]
        )
    }

    private func bundle(of icon: IconComposerDescriptorFile, editingJSON edit: (String) -> String) throws -> URL {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).icon")
        try icon.write(to: bundle)
        let descriptorURL = IconBundle.descriptorURL(in: bundle)
        let json = try String(contentsOf: descriptorURL, encoding: .utf8)
        let editedJSON = edit(json)
        try editedJSON.write(to: descriptorURL, atomically: true, encoding: .utf8)
        return bundle
    }

    // MARK: - Layout

    @Test func layersKeepTheirPlaceButLoseTheirMaterials() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        let card = try #require(blueprint.allLayers.first)

        #expect(card.name == "Card")
        #expect(card.imageName == "Card.svg")
        #expect(card.position == cardPosition)
        #expect(card.glass == false)
        #expect(card.opacity == nil)
    }

    @Test func groupsAreMatte() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        let groups = blueprint.document.groups
        #expect(groups.allSatisfy { $0.shadow?.kind == IconShadow.Kind.none && $0.translucency == .disabled })
    }

    @Test func iconFillIsTheMiddleBackgroundColor() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        let middleColor = try parseHexIconColor(BlueprintStyle.xcodeBackgroundColors[1])
        #expect(blueprint.document.fill == .solid(middleColor))
    }

    @Test func groupsAndLayersAreNamedForIconComposer() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        let groups = blueprint.document.groups

        #expect(groups.map(\.name) == ["Drawing", "Blueprint Paper"])
        #expect(groups[0].layers.map(\.name) == ["Card"])
        #expect(groups[1].layers.map(\.name) == ["Grid", "Background"])
        #expect(groups[1].layers.map(\.imageName) == ["Grid.svg", "Background.svg"])
    }

    @Test func everyLayerHasItsImage() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        #expect(blueprint.validateAssets().isEmpty)
    }

    // MARK: - Paper

    @Test func withoutGridOnlyTheBackgroundRemains() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle(showsGrid: false))

        #expect(blueprint.document.groups.last?.layers.map(\.name) == ["Background"])
        #expect(blueprint.assets["Grid.svg"] == nil)
    }

    @Test func backgroundIsAGradientOfTheStyleColors() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())
        let backgroundData = try #require(blueprint.assets["Background.svg"])
        let background = String(decoding: backgroundData, as: UTF8.self)

        #expect(BlueprintStyle.xcodeBackgroundColors.allSatisfy(background.contains))
    }

    // MARK: - Badge

    @Test func badgeIsAGroupInFrontOfTheDrawing() throws {
        let style = try BlueprintStyle(badge: BlueprintBadge(text: "UAT"))
        let blueprint = try icon().blueprint(style: style)
        let groups = blueprint.document.groups

        #expect(groups.map(\.name) == ["Badge", "Drawing", "Blueprint Paper"])
        #expect(groups[0].layers.map(\.imageName) == ["Badge.svg"])
        #expect(blueprint.assets["Badge.svg"] != nil)
        #expect(blueprint.validateAssets().isEmpty)
    }

    @Test func withoutBadgeThereIsNoBadgeGroup() throws {
        let blueprint = try icon().blueprint(style: BlueprintStyle())

        #expect(!blueprint.document.groups.contains { $0.name == "Badge" })
        #expect(blueprint.assets["Badge.svg"] == nil)
    }

    @Test func layerNamedBadgeKeepsItsOutline() throws {
        var icon = icon()
        icon.document.groups[0].layers = [IconLayer(name: "Badge", imageName: "Card.svg")]

        let blueprint = try icon.blueprint(style: BlueprintStyle(badge: BlueprintBadge(text: "DEV")))

        #expect(blueprint.document.groups[1].layers.map(\.imageName) == ["Badge 2.svg"])
        #expect(blueprint.assets["Badge 2.svg"] != nil)
    }

    // MARK: - File Names

    @Test func layersWithTheSameNameGetNumberedFiles() throws {
        var icon = icon()
        icon.document.groups[0].layers = [
            IconLayer(name: "Background", imageName: "Card.svg"),
            IconLayer(name: "Background", imageName: "Other.svg"),
        ]
        icon.assets["Other.svg"] = cardImage

        let blueprint = try icon.blueprint(style: BlueprintStyle())
        let fileNames = Set(blueprint.assets.keys)
        #expect(fileNames == ["Background 2.svg", "Background 3.svg", "Grid.svg", "Background.svg"])
    }

    // MARK: - Reading Icon Composer Files

    @Test func readsLayersWithFillNone() throws {
        let bundle = try bundle(of: icon()) {
            $0.replacingOccurrences(of: #""glass" : true"#, with: #""fill" : "none", "glass" : true"#)
        }
        defer { try? FileManager.default.removeItem(at: bundle) }

        #expect(throws: (any Error).self) { try IconComposerDescriptorFile(contentsOf: bundle) }
        let layout = try IconComposerDescriptorFile.readingLayout(of: bundle)
        #expect(layout.allLayers.first?.fill == nil)
    }

    @Test func readsGroupsWithLayerColorShadows() throws {
        let bundle = try bundle(of: icon()) {
            $0.replacingOccurrences(of: #""kind" : "neutral""#, with: #""kind" : "layer-color""#)
        }
        defer { try? FileManager.default.removeItem(at: bundle) }

        #expect(throws: (any Error).self) { try IconComposerDescriptorFile(contentsOf: bundle) }
        let layout = try IconComposerDescriptorFile.readingLayout(of: bundle)
        #expect(layout.allLayers.first?.position == cardPosition)
    }

    @Test func readsAndKeepsPlatformSpecificSquares() throws {
        var icon = icon()
        icon.document.supportedPlatforms = SupportedPlatforms(squares: .shared)
        let bundle = try bundle(of: icon) {
            $0.replacingOccurrences(of: #""squares" : "shared""#, with: #""squares" : ["iOS", "macOS"]"#)
        }
        defer { try? FileManager.default.removeItem(at: bundle) }

        #expect(throws: (any Error).self) { try IconComposerDescriptorFile(contentsOf: bundle) }
        let layout = try IconComposerDescriptorFile.readingLayout(of: bundle)
        #expect(layout.document.supportedPlatforms?.squares == .platforms(["iOS", "macOS"]))

        let output = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).icon")
        defer { try? FileManager.default.removeItem(at: output) }
        try layout.blueprint(style: BlueprintStyle()).writeKeepingLayerColors(to: output)
        let descriptorData = try Data(contentsOf: IconBundle.descriptorURL(in: output))
        let descriptor = try #require(try JSONSerialization.jsonObject(with: descriptorData) as? JSONObject)
        let supportedPlatforms = try #require(descriptor["supported-platforms"] as? JSONObject)
        #expect(supportedPlatforms["squares"] as? [String] == ["iOS", "macOS"])
    }
}

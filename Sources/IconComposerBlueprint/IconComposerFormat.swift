import BlueprintCore
import Foundation
import IconKit

/// Icon Composer's `.icon` bundles: layered icons, redrawn layer by layer.
package struct IconComposerFormat: IconFormat {
    package let fileExtension = "icon"

    package init() {}

    package func blueprint(of source: URL, style: BlueprintStyle) throws -> any IconBlueprint {
        let original = try IconComposerDescriptorFile.readingLayout(of: source)
        let blueprint = try original.blueprint(style: style)
        return IconComposerBlueprint(file: blueprint, layerCount: original.allLayers.count)
    }

    /// Blueprints are recognized by their "Blueprint Paper" group, and blueprints
    /// drawn by version 1.0 by their single `Blueprint Paper.svg` image.
    package func isBlueprint(_ url: URL) -> Bool {
        let hasPaperGroup = groupNames(in: url).contains(IconComposerDescriptorFile.paperGroupName)
        return hasPaperGroup || hasVersion1Paper(url)
    }

    private let version1PaperFileName = "Blueprint Paper.svg"

    private func hasVersion1Paper(_ url: URL) -> Bool {
        let assetsURL = IconBundle.assetsURL(in: url)
        let paperURL = assetsURL.appendingPathComponent(version1PaperFileName)
        return FileManager.default.fileExists(atPath: paperURL.path)
    }

    private func groupNames(in url: URL) -> [String] {
        let descriptorURL = IconBundle.descriptorURL(in: url)
        guard let descriptorData = FileManager.default.contents(atPath: descriptorURL.path),
              let descriptor = try? JSONSerialization.jsonObject(with: descriptorData) as? JSONObject,
              let groups = descriptor["groups"] as? [JSONObject] else { return [] }
        return groups.compactMap { $0["name"] as? String }
    }
}

/// An `.icon` blueprint, ready to be saved.
struct IconComposerBlueprint: IconBlueprint {
    let file: IconComposerDescriptorFile
    let layerCount: Int

    func write(to bundleURL: URL) throws {
        try file.writeKeepingLayerColors(to: bundleURL)
    }
}

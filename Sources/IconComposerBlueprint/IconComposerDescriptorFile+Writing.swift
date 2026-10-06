import BlueprintCore
import Foundation
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Writing an Icon

    /// Writes the icon as an `.icon` bundle whose layers keep their own colors in
    /// every appearance.
    ///
    /// Each layer gets `"fill": "none"`, Icon Composer's setting for showing an image
    /// in its own colors. Without it, the dark and tinted appearances recolor the white
    /// outlines to match the blue background, and they disappear. IconKit 1.2 has no
    /// case for `none`, so it's added to `icon.json` after IconKit writes the bundle.
    func writeKeepingLayerColors(to bundleURL: URL) throws {
        try write(to: bundleURL)

        let descriptorURL = IconBundle.descriptorURL(in: bundleURL)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let writtenDescriptor = try JSONSerialization.jsonObject(with: descriptorData)
        guard var descriptor = writtenDescriptor as? JSONObject,
              let groups = descriptor["groups"] as? [JSONObject] else { throw BlueprintError.unexpectedIconLayout }

        descriptor["groups"] = try groups.map(Self.keepingLayerColors)

        let updatedData = try JSONSerialization.data(withJSONObject: descriptor, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try updatedData.write(to: descriptorURL)
    }

    private static func keepingLayerColors(_ group: JSONObject) throws -> JSONObject {
        guard let layers = group["layers"] as? [JSONObject] else { throw BlueprintError.unexpectedIconLayout }
        let layersInOwnColors = layers.map { layer in
            var layer = layer
            layer["fill"] = "none"
            return layer
        }
        var group = group
        group["layers"] = layersInOwnColors
        return group
    }
}

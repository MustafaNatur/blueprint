import Foundation
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Writing an Icon

    /// Writes the icon to `destination`, replacing whatever is there only once the
    /// new bundle is complete.
    ///
    /// The bundle is first written to a hidden folder next to `destination` and then
    /// moved into place, so a failed write leaves `destination` as it was. The hidden
    /// folder is always removed.
    func write(replacing destination: URL) throws {
        let fileManager = FileManager.default
        let folder = destination.deletingLastPathComponent()
        let stagingName = ".\(destination.lastPathComponent)-\(UUID().uuidString)"
        let staging = folder.appendingPathComponent(stagingName)
        defer { try? fileManager.removeItem(at: staging) }

        try writeKeepingLayerColors(to: staging)
        let destinationIsTaken = fileManager.fileExists(atPath: destination.path)
        if destinationIsTaken {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
    }

    /// Writes the icon as an `.icon` bundle whose layers keep their own colors in
    /// every appearance.
    ///
    /// Each layer gets `"fill": "none"`, Icon Composer's setting for showing an image
    /// in its own colors. Without it, the dark and tinted appearances recolor the white
    /// outlines to match the blue background, and they disappear. IconKit 1.2 has no
    /// case for `none`, so it's added to `icon.json` after IconKit writes the bundle.
    private func writeKeepingLayerColors(to bundleURL: URL) throws {
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

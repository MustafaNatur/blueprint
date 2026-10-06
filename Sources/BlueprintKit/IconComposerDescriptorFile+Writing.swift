import Foundation
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Writing an Icon

    /// Writes the icon as an `.icon` bundle whose layers keep their own colors in
    /// every appearance.
    ///
    /// Each layer gets `"fill": "none"`, Icon Composer's setting for showing an image
    /// in its own colors. Without it, the dark and tinted appearances recolor the white
    /// outlines to match the blue paper, and they disappear. IconKit 1.2 has no case
    /// for `none`, so it's added to `icon.json` after IconKit writes the bundle.
    ///
    /// - Parameter bundleURL: Where to write the `.icon` bundle.
    /// - Throws: An error if the bundle can't be written.
    func writeKeepingLayerColors(to bundleURL: URL) throws {
        try write(to: bundleURL)

        let jsonURL = bundleURL.appendingPathComponent("icon.json")
        guard var json = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonURL)) as? [String: Any],
              let groups = json["groups"] as? [[String: Any]] else { return }
        json["groups"] = groups.map { group in
            var group = group
            group["layers"] = (group["layers"] as? [[String: Any]])?.map { layer in
                var layer = layer
                layer["fill"] = "none"
                return layer
            }
            return group
        }
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            .write(to: jsonURL)
    }
}

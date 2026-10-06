import Foundation
import IconKit

extension IconComposerDescriptorFile {
    /// Writes the bundle with every layer set to `"fill": "none"`, Icon Composer's
    /// "keep the image's own colors". Without it the dark and tinted appearances
    /// recolor the white outlines to match the blue paper, and they disappear.
    /// IconKit 1.2 has no case for `none`, so it's added to `icon.json` after writing.
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

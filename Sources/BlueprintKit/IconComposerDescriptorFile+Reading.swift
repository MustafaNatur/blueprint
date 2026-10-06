import Foundation
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Reading an Icon

    /// Reads the layout of an `.icon` bundle: its groups, layers, images, positions
    /// and visibility.
    ///
    /// Fills, shadows, glass, blend modes and other materials are left out before
    /// decoding, because a blueprint replaces them. That also avoids values Icon
    /// Composer writes that IconKit 1.2 can't decode, such as `"fill": "none"` and
    /// the `"layer-color"` shadow.
    ///
    /// - Parameter bundleURL: The location of the `.icon` bundle.
    /// - Returns: The icon's layout and every file in its `Assets` folder.
    /// - Throws: An error if `icon.json` or an asset can't be read or decoded.
    static func reading(_ bundleURL: URL) throws -> IconComposerDescriptorFile {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: bundleURL.appendingPathComponent("icon.json")))
        let layout = try JSONSerialization.data(withJSONObject: withoutMaterials(json))
        let document = try JSONDecoder().decode(IconDocument.self, from: layout)

        let assetsURL = bundleURL.appendingPathComponent("Assets")
        let files = (try? FileManager.default.contentsOfDirectory(at: assetsURL, includingPropertiesForKeys: nil)) ?? []
        let assets = try Dictionary(uniqueKeysWithValues: files.map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
        return IconComposerDescriptorFile(document: document, assets: assets)
    }

    /// The `icon.json` properties that describe materials rather than layout.
    private static let materialKeys: Set<String> = [
        "fill", "shadow", "translucency", "blend-mode", "lighting", "specular", "glass", "opacity", "blur-material",
    ]

    /// Returns the JSON value with every material property and its specializations removed, at any depth.
    private static func withoutMaterials(_ value: Any) -> Any {
        switch value {
        case let dictionary as [String: Any]:
            dictionary.reduce(into: [String: Any]()) { result, entry in
                let property = entry.key.replacingOccurrences(of: "-specializations", with: "")
                if !materialKeys.contains(property) {
                    result[entry.key] = withoutMaterials(entry.value)
                }
            }
        case let array as [Any]:
            array.map(withoutMaterials)
        default:
            value
        }
    }
}

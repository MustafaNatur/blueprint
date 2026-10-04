import Foundation
import IconKit

extension IconComposerDescriptorFile {
    /// Reads an `.icon` bundle for redrawing, keeping only its layout: groups,
    /// layers, images, positions and visibility.
    ///
    /// Fills, shadows, glass and blend modes are dropped before decoding, since
    /// the blueprint replaces them anyway. IconKit 1.2 also can't decode some
    /// values Icon Composer writes there, such as `"fill": "none"` and the
    /// `"layer-color"` shadow.
    static func reading(_ bundleURL: URL) throws -> IconComposerDescriptorFile {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: bundleURL.appendingPathComponent("icon.json")))
        let layout = try JSONSerialization.data(withJSONObject: withoutMaterials(json))
        let document = try JSONDecoder().decode(IconDocument.self, from: layout)

        let assetsURL = bundleURL.appendingPathComponent("Assets")
        let files = (try? FileManager.default.contentsOfDirectory(at: assetsURL, includingPropertiesForKeys: nil)) ?? []
        let assets = try Dictionary(uniqueKeysWithValues: files.map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
        return IconComposerDescriptorFile(document: document, assets: assets)
    }

    private static let materialKeys: Set<String> = [
        "fill", "shadow", "translucency", "blend-mode", "lighting", "specular", "glass", "opacity", "blur-material",
    ]

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

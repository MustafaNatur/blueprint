import BlueprintCore
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
    static func readingLayout(of bundleURL: URL) throws -> IconComposerDescriptorFile {
        let descriptorURL = IconBundle.descriptorURL(in: bundleURL)
        let descriptorData = try Data(contentsOf: descriptorURL)
        let descriptor = try JSONSerialization.jsonObject(with: descriptorData)

        let layout = withoutMaterials(descriptor)
        let layoutData = try JSONSerialization.data(withJSONObject: layout)
        let document = try JSONDecoder().decode(IconDocument.self, from: layoutData)

        let assets = try assetFiles(in: bundleURL)
        return IconComposerDescriptorFile(document: document, assets: assets)
    }

    private static func assetFiles(in bundleURL: URL) throws -> [String: Data] {
        let assetsURL = IconBundle.assetsURL(in: bundleURL)
        let fileURLs = (try? FileManager.default.contentsOfDirectory(at: assetsURL, includingPropertiesForKeys: nil)) ?? []

        var files: [String: Data] = [:]
        for fileURL in fileURLs {
            files[fileURL.lastPathComponent] = try Data(contentsOf: fileURL)
        }
        return files
    }

    // MARK: - Materials

    /// The `icon.json` properties that describe materials rather than layout.
    private static let materialProperties: Set<String> = [
        "fill", "shadow", "translucency", "blend-mode", "lighting", "specular", "glass", "opacity", "blur-material",
    ]

    /// Returns the JSON value with every material property and its specializations removed, at any depth.
    private static func withoutMaterials(_ value: Any) -> Any {
        switch value {
        case let object as JSONObject:
            let layoutProperties = object.filter { !isMaterial($0.key) }
            return layoutProperties.mapValues(withoutMaterials)
        case let array as [Any]:
            return array.map(withoutMaterials)
        default:
            return value
        }
    }

    /// Whether a key names a material property, like `"shadow"`, or its specializations, like `"shadow-specializations"`.
    private static func isMaterial(_ key: String) -> Bool {
        let suffix = "-specializations"
        let property = key.hasSuffix(suffix) ? String(key.dropLast(suffix.count)) : key
        return materialProperties.contains(property)
    }
}

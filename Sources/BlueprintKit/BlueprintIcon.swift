import Foundation
import IconKit

/// Draws blueprint versions of Icon Composer icons and recognizes the ones it drew.
///
/// A blueprint keeps every layer of the original icon in its place, but draws it as a
/// white outline on blue graph paper, in the style of Xcode's icon. Use it as the app
/// icon of debug builds to tell them apart from the App Store app at a glance.
///
/// ```swift
/// let source = URL(fileURLWithPath: "MyApp/AppIcon.icon")
/// let destination = URL(fileURLWithPath: "MyApp/AppIconDebug.icon")
///
/// try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
/// ```
public enum BlueprintIcon {

    // MARK: - Drawing a Blueprint

    /// Draws a blueprint of an icon and saves it as a new `.icon` bundle.
    ///
    /// The blueprint is written next to the destination first and then moved into
    /// place, so a failure never leaves a half-written icon behind. A blueprint
    /// drawn earlier at `destination` is replaced; any other icon there is left
    /// untouched and the call throws instead.
    ///
    /// - Parameters:
    ///   - source: The Icon Composer `.icon` bundle to redraw.
    ///   - destination: Where to save the blueprint `.icon` bundle.
    ///   - style: The paper colors, line width and grid of the blueprint.
    /// - Returns: The number of layers in the original icon.
    /// - Throws: ``BlueprintError/alreadyBlueprint(_:)`` when `source` is itself a
    ///   blueprint, ``BlueprintError/wouldOverwriteIcon(_:)`` when `destination` holds
    ///   an icon blueprint didn't draw, and any error from reading or writing the files.
    @discardableResult
    public static func generate(from source: URL, to destination: URL, style: BlueprintStyle) throws -> Int {
        let fileManager = FileManager.default
        if isBlueprint(source) {
            throw BlueprintError.alreadyBlueprint(source.lastPathComponent)
        }
        if fileManager.fileExists(atPath: destination.path), !isBlueprint(destination) {
            throw BlueprintError.wouldOverwriteIcon(destination.lastPathComponent)
        }

        let original = try IconComposerDescriptorFile.reading(source)
        let blueprint = try original.blueprint(style: style)

        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent)-\(UUID().uuidString)")
        try blueprint.writeKeepingLayerColors(to: staging)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
        return original.document.groups.flatMap(\.layers).count
    }

    // MARK: - Recognizing a Blueprint

    /// Returns a Boolean value that indicates whether blueprint drew the icon at a URL.
    ///
    /// Blueprints are recognized by their "Blueprint Paper" group, and blueprints
    /// drawn by version 1.0 by their single `Blueprint Paper.svg` image.
    ///
    /// - Parameter url: The location of an `.icon` bundle.
    /// - Returns: `true` if the icon is a blueprint; otherwise, `false`, including
    ///   when there's no readable icon at `url`.
    public static func isBlueprint(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Assets/Blueprint Paper.svg").path) {
            return true
        }
        guard let data = FileManager.default.contents(atPath: url.appendingPathComponent("icon.json").path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["groups"] as? [[String: Any]] else { return false }
        return groups.contains { $0["name"] as? String == IconComposerDescriptorFile.paperGroupName }
    }
}

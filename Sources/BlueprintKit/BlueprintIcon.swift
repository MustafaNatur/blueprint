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
    /// A blueprint drawn earlier at `destination` is replaced. Any other icon there is
    /// left untouched, and the call throws instead.
    ///
    /// - Parameters:
    ///   - source: The Icon Composer `.icon` bundle to redraw.
    ///   - destination: Where to save the blueprint `.icon` bundle.
    ///   - style: The background colors, line width and grid of the blueprint.
    /// - Returns: The number of layers in the original icon.
    /// - Throws: ``BlueprintError/alreadyBlueprint(_:)`` when `source` is itself a
    ///   blueprint, ``BlueprintError/wouldOverwriteIcon(_:)`` when `destination` holds
    ///   an icon blueprint didn't draw, and any error from reading or writing the files.
    @discardableResult
    public static func generate(from source: URL, to destination: URL, style: BlueprintStyle) throws -> Int {
        try ensureCanDraw(from: source, to: destination)
        let original = try IconComposerDescriptorFile.readingLayout(of: source)
        let blueprint = try original.blueprint(style: style)
        try blueprint.write(replacing: destination)
        return original.allLayers.count
    }

    private static func ensureCanDraw(from source: URL, to destination: URL) throws {
        if isBlueprint(source) {
            throw BlueprintError.alreadyBlueprint(source.lastPathComponent)
        }
        let destinationIsTaken = FileManager.default.fileExists(atPath: destination.path)
        if destinationIsTaken, !isBlueprint(destination) {
            throw BlueprintError.wouldOverwriteIcon(destination.lastPathComponent)
        }
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
        let hasPaperGroup = groupNames(in: url).contains(IconComposerDescriptorFile.paperGroupName)
        return hasPaperGroup || hasVersion1Paper(url)
    }

    private static let version1PaperFileName = "Blueprint Paper.svg"

    private static func hasVersion1Paper(_ url: URL) -> Bool {
        let assetsURL = IconBundle.assetsURL(in: url)
        let paperURL = assetsURL.appendingPathComponent(version1PaperFileName)
        return FileManager.default.fileExists(atPath: paperURL.path)
    }

    private static func groupNames(in url: URL) -> [String] {
        let descriptorURL = IconBundle.descriptorURL(in: url)
        guard let descriptorData = FileManager.default.contents(atPath: descriptorURL.path),
              let descriptor = try? JSONSerialization.jsonObject(with: descriptorData) as? JSONObject,
              let groups = descriptor["groups"] as? [JSONObject] else { return [] }
        return groups.compactMap { $0["name"] as? String }
    }
}

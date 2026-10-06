import Foundation

/// Draws blueprint versions of app icons and recognizes the ones it drew.
///
/// A blueprint keeps the shapes of the original icon in their place, but draws them as
/// white outlines on blue graph paper, in the style of Xcode's icon. Use it as the app
/// icon of debug builds to tell them apart from the App Store app at a glance.
///
/// It reads Icon Composer `.icon` files and asset catalog `.appiconset` folders, and
/// saves the blueprint in the same format as the original.
///
/// ```swift
/// let source = URL(fileURLWithPath: "MyApp/Assets.xcassets/AppIcon.appiconset")
/// let destination = URL(fileURLWithPath: "MyApp/Assets.xcassets/AppIconDebug.appiconset")
///
/// try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
/// ```
public enum BlueprintIcon {

    // MARK: - Drawing a Blueprint

    /// Draws a blueprint of an icon and saves it in the same format.
    ///
    /// A blueprint drawn earlier at `destination` is replaced. Any other icon there is
    /// left untouched, and the call throws instead.
    ///
    /// - Parameters:
    ///   - source: The `.icon` or `.appiconset` to redraw.
    ///   - destination: Where to save the blueprint, with the same file extension as `source`.
    ///   - style: The background colors, line width and grid of the blueprint.
    /// - Returns: The number of layers traced from the original icon.
    /// - Throws: ``BlueprintError/unsupportedFormat(_:)`` for other files,
    ///   ``BlueprintError/formatMismatch(_:_:)`` when the destination's extension differs,
    ///   ``BlueprintError/alreadyBlueprint(_:)`` when `source` is itself a blueprint,
    ///   ``BlueprintError/wouldOverwriteIcon(_:)`` when `destination` holds an icon
    ///   blueprint didn't draw, and any error from reading or writing the files.
    @discardableResult
    public static func generate(from source: URL, to destination: URL, style: BlueprintStyle) throws -> Int {
        let format = try IconFormats.format(of: source)
        try ensureCanDraw(from: source, to: destination, in: format)

        let blueprint = try format.blueprint(of: source, style: style)
        try FolderReplacement.replace(destination, writing: blueprint.write(to:))
        return blueprint.layerCount
    }

    private static func ensureCanDraw(from source: URL, to destination: URL, in format: any IconFormat) throws {
        if destination.lowercasedExtension != format.fileExtension {
            throw BlueprintError.formatMismatch(source.lastPathComponent, destination.lastPathComponent)
        }
        if format.isBlueprint(source) {
            throw BlueprintError.alreadyBlueprint(source.lastPathComponent)
        }
        let destinationIsTaken = FileManager.default.fileExists(atPath: destination.path)
        if destinationIsTaken, !format.isBlueprint(destination) {
            throw BlueprintError.wouldOverwriteIcon(destination.lastPathComponent)
        }
    }

    // MARK: - Recognizing a Blueprint

    /// Returns a Boolean value that indicates whether blueprint drew the icon at a URL.
    ///
    /// - Parameter url: The location of an `.icon` or `.appiconset`.
    /// - Returns: `true` if the icon is a blueprint; otherwise, `false`, including when
    ///   there's no readable icon at `url` or it's in another format.
    public static func isBlueprint(_ url: URL) -> Bool {
        guard let format = try? IconFormats.format(of: url) else { return false }
        return format.isBlueprint(url)
    }
}

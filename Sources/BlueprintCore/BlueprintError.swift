import Foundation

/// An error that occurs while drawing a blueprint.
///
/// ``errorDescription`` turns each case into a message that can be shown to the user as is.
public enum BlueprintError: Error, LocalizedError, Equatable {

    /// A layer image couldn't be read as an image.
    ///
    /// The associated value is the name of the image in the icon's `Assets` folder.
    case unreadableLayerImage(String)

    /// The icon refers to a layer image that isn't in its `Assets` folder.
    ///
    /// The associated value is the name of the missing image.
    case missingLayerImage(String)

    /// The destination already holds an icon that blueprint didn't draw.
    ///
    /// The associated value is the name of that icon.
    case wouldOverwriteIcon(String)

    /// The source icon is a blueprint itself.
    ///
    /// The associated value is the name of the source icon.
    case alreadyBlueprint(String)

    /// A background color isn't a `#RRGGBB` hex string.
    ///
    /// The associated value is the color as given.
    case invalidColor(String)

    /// The file isn't an `.icon` or `.appiconset`.
    ///
    /// The associated value is the name of the file.
    case unsupportedFormat(String)

    /// The destination's file extension doesn't match the source's format.
    ///
    /// The associated values are the names of the source and the destination.
    case formatMismatch(String, String)

    /// The `.appiconset` has no image to redraw.
    ///
    /// The associated value is the name of the icon set.
    case emptyIconSet(String)

    /// Vision found nothing in front of the background of a flat icon.
    case noForeground

    /// Core Image or Image I/O failed to process a layer.
    case imageProcessingFailed

    /// IconKit wrote an `icon.json` without the groups and layers blueprint expects.
    case unexpectedIconLayout

    /// A message describing the error, suitable for showing to the user.
    public var errorDescription: String? {
        switch self {
        case .unreadableLayerImage(let name):
            "Couldn't read the layer image \(name)."
        case .missingLayerImage(let name):
            "The icon refers to \(name), but it isn't in the Assets folder."
        case .wouldOverwriteIcon(let name):
            "\(name) already exists and isn't a blueprint icon."
        case .alreadyBlueprint(let name):
            "\(name) is already a blueprint. Pass the original icon instead."
        case .invalidColor(let color):
            "\(color.isEmpty ? "No color" : color) isn't a #RRGGBB hex color."
        case .unsupportedFormat(let name):
            "\(name) isn't an .icon or .appiconset."
        case .formatMismatch(let source, let destination):
            "\(destination) needs the same file extension as \(source)."
        case .emptyIconSet(let name):
            "\(name) has no image to redraw."
        case .noForeground:
            "Couldn't find anything in front of the icon's background."
        case .imageProcessingFailed:
            "Image processing failed."
        case .unexpectedIconLayout:
            "The written icon.json doesn't have the expected groups and layers."
        }
    }
}

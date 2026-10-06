import Foundation

/// An error that occurs while drawing a blueprint.
///
/// Each case carries the file name involved, and ``errorDescription`` turns it into
/// a message that can be shown to the user as is.
public enum BlueprintError: Error, LocalizedError {

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

    /// Core Image or Image I/O failed to process a layer.
    case imageProcessingFailed

    /// A message describing the error, suitable for showing to the user.
    public var errorDescription: String? {
        switch self {
        case .unreadableLayerImage(let name):
            "Couldn't read the layer image \(name)."
        case .missingLayerImage(let name):
            "The icon refers to \(name), but it isn't in the Assets folder."
        case .wouldOverwriteIcon(let name):
            "\(name) already exists and isn't a blueprint icon. Pick another name with --output."
        case .alreadyBlueprint(let name):
            "\(name) is already a blueprint. Pass the original icon instead."
        case .imageProcessingFailed:
            "Image processing failed."
        }
    }
}

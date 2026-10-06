import Foundation

public enum BlueprintError: Error, LocalizedError {
    case unreadableLayerImage(String)
    case missingLayerImage(String)
    case wouldOverwriteIcon(String)
    case alreadyBlueprint(String)
    case imageProcessingFailed

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

import Foundation

/// The names of the files inside an Icon Composer `.icon` bundle.
enum IconBundle {
    static let descriptorFileName = "icon.json"
    static let assetsFolderName = "Assets"

    static func descriptorURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(descriptorFileName)
    }

    static func assetsURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(assetsFolderName)
    }
}

/// A decoded JSON object, as `JSONSerialization` returns it.
typealias JSONObject = [String: Any]

extension String {
    /// The file name without its extension: `"Card.svg"` becomes `"Card"`.
    var withoutExtension: String {
        (self as NSString).deletingPathExtension
    }
}

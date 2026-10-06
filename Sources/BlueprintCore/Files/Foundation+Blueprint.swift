import Foundation

/// A decoded JSON object, as `JSONSerialization` returns it.
package typealias JSONObject = [String: Any]

extension String {
    /// The file name without its extension: `"Card.svg"` becomes `"Card"`.
    package var withoutExtension: String {
        (self as NSString).deletingPathExtension
    }
}

extension URL {
    /// The URL's file extension, lowercased: `"AppIcon.ICON"` gives `"icon"`.
    package var lowercasedExtension: String {
        pathExtension.lowercased()
    }
}

import Foundation

/// A decoded JSON object, as `JSONSerialization` returns it.
typealias JSONObject = [String: Any]

extension String {
    /// The file name without its extension: `"Card.svg"` becomes `"Card"`.
    var withoutExtension: String {
        (self as NSString).deletingPathExtension
    }
}

extension URL {
    /// The URL's file extension, lowercased: `"AppIcon.ICON"` gives `"icon"`.
    var lowercasedExtension: String {
        pathExtension.lowercased()
    }
}

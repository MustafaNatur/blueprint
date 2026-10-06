import Foundation

/// Writes the small SVG documents a blueprint is made of.
package enum SVG {
    /// Returns an SVG document of the given size in points.
    package static func document(width: Double, height: Double, body: String) -> Data {
        let width = number(width), height = number(height)
        let document = """
        <svg width='\(width)' height='\(height)' viewBox='0 0 \(width) \(height)' xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>
        \(body)
        </svg>

        """
        return Data(document.utf8)
    }

    /// Returns an element that stretches a PNG over the whole document.
    package static func image(png: Data, width: Double, height: Double) -> String {
        let width = number(width), height = number(height)
        let base64 = png.base64EncodedString()
        return "<image width='\(width)' height='\(height)' preserveAspectRatio='none' xlink:href='data:image/png;base64,\(base64)'/>"
    }

    /// Returns a whole number without decimals, and any other number with three.
    package static func number(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.3f", value)
    }
}

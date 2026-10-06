import Foundation

/// The SVG images of the paper behind a blueprint drawing.
///
/// Both images cover the whole 1024-point icon canvas. The background is a vertical
/// gradient; the grid divides the canvas into 4 × 4 equal squares.
enum BlueprintPaper {

    // MARK: - Canvas

    /// The width and height of the icon canvas, in points.
    static let canvas = 1024

    /// The distance between grid lines, in points.
    static let gridStep = canvas / 4

    // MARK: - Images

    /// Returns an SVG of the paper's gradient, running from the first color at the
    /// top to the last color at the bottom.
    ///
    /// - Parameter colors: The gradient colors as hex strings, top to bottom.
    static func background(colors: [String]) -> Data {
        let stops = colors.enumerated().map { index, color in
            let offset = colors.count == 1 ? 0 : Double(index) / Double(colors.count - 1)
            return #"<stop offset="\#(offset)" stop-color="\#(color)"/>"#
        }
        return svg("""
        <defs><linearGradient id="paper" x1="0" y1="0" x2="0" y2="1">\(stops.joined())</linearGradient></defs>
        <rect width="\(canvas)" height="\(canvas)" fill="url(#paper)"/>
        """)
    }

    /// Returns an SVG of the 4 × 4 grid, as white lines on a transparent background.
    static func grid() -> Data {
        let style = ##"stroke="#fff" stroke-opacity="0.55" stroke-width="5""##
        let lines = stride(from: 0, through: canvas, by: gridStep).flatMap { offset in
            [
                #"<line x1="\#(offset)" y1="0" x2="\#(offset)" y2="\#(canvas)" \#(style)/>"#,
                #"<line x1="0" y1="\#(offset)" x2="\#(canvas)" y2="\#(offset)" \#(style)/>"#,
            ]
        }
        return svg(lines.joined(separator: "\n"))
    }

    private static func svg(_ content: String) -> Data {
        Data("""
        <svg width="\(canvas)" height="\(canvas)" viewBox="0 0 \(canvas) \(canvas)" xmlns="http://www.w3.org/2000/svg">
        \(content)
        </svg>

        """.utf8)
    }
}

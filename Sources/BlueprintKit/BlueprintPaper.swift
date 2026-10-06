import Foundation

/// The paper behind the traced layers: a top-to-bottom gradient like Xcode's icon,
/// and on top of it a 4 × 4 grid.
enum BlueprintPaper {
    static let canvas = 1024
    static let gridStep = canvas / 4

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

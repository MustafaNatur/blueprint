import Foundation

/// The paper behind the traced layers: a top-to-bottom gradient like Xcode's icon,
/// and on top of it a 32 pt grid that's heavier every 128 pt, with Apple's
/// icon-template guide circles and diagonals.
enum BlueprintPaper {
    static let canvas = 1024
    static let minorStep = 32
    static let majorStep = 128

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
        let lines = stride(from: 0, through: canvas, by: minorStep).flatMap { offset in
            let isMajor = offset % majorStep == 0
            let style = ##"stroke="#fff" stroke-opacity="\##(isMajor ? "0.45" : "0.2")" stroke-width="\##(isMajor ? 3 : 1.5)""##
            return [
                #"<line x1="\#(offset)" y1="0" x2="\#(offset)" y2="\#(canvas)" \#(style)/>"#,
                #"<line x1="0" y1="\#(offset)" x2="\#(canvas)" y2="\#(offset)" \#(style)/>"#,
            ]
        }
        let center = canvas / 2
        return svg("""
        \(lines.joined(separator: "\n"))
        <g stroke="#fff" stroke-opacity="0.35" stroke-width="2.5" fill="none" stroke-dasharray="10 8">
        <circle cx="\(center)" cy="\(center)" r="384"/>
        <circle cx="\(center)" cy="\(center)" r="208"/>
        <line x1="0" y1="0" x2="\(canvas)" y2="\(canvas)"/>
        <line x1="\(canvas)" y1="0" x2="0" y2="\(canvas)"/>
        </g>
        """)
    }

    private static func svg(_ content: String) -> Data {
        Data("""
        <svg width="\(canvas)" height="\(canvas)" viewBox="0 0 \(canvas) \(canvas)" xmlns="http://www.w3.org/2000/svg">
        \(content)
        </svg>

        """.utf8)
    }
}

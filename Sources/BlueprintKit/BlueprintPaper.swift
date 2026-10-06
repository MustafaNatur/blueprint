import Foundation

/// The images of the paper behind a blueprint drawing: a vertical color gradient,
/// and a grid that divides the icon into 4 × 4 equal squares.
enum BlueprintPaper {

    // MARK: - Measurements

    static let canvasSize = 1024.0
    static let gridDivisions = 4
    static let gridLineWidth = 5.0
    static let gridLineOpacity = 0.55

    // MARK: - Images

    /// Returns an SVG of the background gradient, from the first color at the top
    /// to the last color at the bottom.
    static func background(colors: [String]) -> Data {
        let stops = gradientStops(colors)
        let size = SVG.number(canvasSize)
        let body = """
        <defs><linearGradient id='background' x1='0' y1='0' x2='0' y2='1'>\(stops)</linearGradient></defs>
        <rect width='\(size)' height='\(size)' fill='url(#background)'/>
        """
        return SVG.document(width: canvasSize, height: canvasSize, body: body)
    }

    /// Returns an SVG of the grid, as white lines on a transparent background.
    static func grid() -> Data {
        let lines = gridLinePositions.flatMap { position in
            let vertical = gridLine(from: (position, 0), to: (position, canvasSize))
            let horizontal = gridLine(from: (0, position), to: (canvasSize, position))
            return [vertical, horizontal]
        }
        let body = lines.joined(separator: "\n")
        return SVG.document(width: canvasSize, height: canvasSize, body: body)
    }

    // MARK: - Parts

    private static func gradientStops(_ colors: [String]) -> String {
        let stops = colors.enumerated().map { index, color in
            let offset = colors.count == 1 ? 0 : Double(index) / Double(colors.count - 1)
            return "<stop offset='\(offset)' stop-color='\(color)'/>"
        }
        return stops.joined()
    }

    private static var gridLinePositions: [Double] {
        (0...gridDivisions).map { canvasSize * Double($0) / Double(gridDivisions) }
    }

    private static func gridLine(from start: (x: Double, y: Double), to end: (x: Double, y: Double)) -> String {
        let x1 = SVG.number(start.x), y1 = SVG.number(start.y)
        let x2 = SVG.number(end.x), y2 = SVG.number(end.y)
        let width = SVG.number(gridLineWidth)
        return "<line x1='\(x1)' y1='\(y1)' x2='\(x2)' y2='\(y2)' stroke='white' stroke-opacity='\(gridLineOpacity)' stroke-width='\(width)'/>"
    }
}

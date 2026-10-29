import Foundation

/// The images of the paper behind a blueprint drawing: a vertical color gradient,
/// and a grid that divides the icon into 4 × 4 equal squares.
package enum BlueprintPaper {

    // MARK: - Measurements

    package static let canvasSize = 1024.0
    static let gridDivisions = 4
    static let gridLineWidth = 9.0
    static let gridLineOpacity = 0.25

    // MARK: - Images

    /// Returns an SVG of the background gradient, from the first color at the top
    /// to the last color at the bottom.
    package static func background(colors: [String]) -> Data {
        let stops = gradientStops(colors)
        let size = SVG.number(canvasSize)
        let body = """
        <defs><linearGradient id='background' x1='0' y1='0' x2='0' y2='1'>\(stops)</linearGradient></defs>
        <rect width='\(size)' height='\(size)' fill='url(#background)'/>
        """
        return SVG.document(width: canvasSize, height: canvasSize, body: body)
    }

    /// Returns an SVG of the grid, as white lines on a transparent background.
    ///
    /// As in Xcode's icon, each corner square is outlined along the icon's rounded corner,
    /// and the grid lines next to the corners end where they turn into those outlines.
    /// Only the lines through the middle run from edge to edge.
    package static func grid() -> Data {
        let corner = GridCorner(gridLine: firstGridLine)
        let start = corner.gridLineStart, end = canvasSize - start
        let lines = innerGridLinePositions.flatMap { position in
            let isMiddle = position == canvasSize / 2
            let from = isMiddle ? 0 : start, to = isMiddle ? canvasSize : end
            let vertical = gridLine(from: (position, from), to: (position, to))
            let horizontal = gridLine(from: (from, position), to: (to, position))
            return [vertical, horizontal]
        }
        let corners = cornerMirrors.map { mirror in
            gridOutline(corner.pathData, transform: mirror)
        }
        let strokes = (lines + corners).joined(separator: "\n")
        let body = "<g opacity='\(gridLineOpacity)' stroke='white' stroke-width='\(SVG.number(gridLineWidth))' fill='none'>\n\(strokes)\n</g>"
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

    private static var firstGridLine: Double {
        canvasSize / Double(gridDivisions)
    }

    private static var innerGridLinePositions: [Double] {
        (1..<gridDivisions).map { canvasSize * Double($0) / Double(gridDivisions) }
    }

    /// The transforms that turn the top left corner into each of the four corners.
    private static var cornerMirrors: [String?] {
        let size = SVG.number(canvasSize)
        return [nil, "matrix(-1 0 0 1 \(size) 0)", "matrix(1 0 0 -1 0 \(size))", "matrix(-1 0 0 -1 \(size) \(size))"]
    }

    /// Returns a grid line. Its stroke comes from the group around the grid, which fades
    /// all lines at once so they don't get brighter where they cross.
    private static func gridLine(from start: (x: Double, y: Double), to end: (x: Double, y: Double)) -> String {
        let x1 = SVG.number(start.x), y1 = SVG.number(start.y)
        let x2 = SVG.number(end.x), y2 = SVG.number(end.y)
        return "<line x1='\(x1)' y1='\(y1)' x2='\(x2)' y2='\(y2)'/>"
    }

    private static func gridOutline(_ pathData: String, transform: String?) -> String {
        let transformAttribute = transform.map { " transform='\($0)'" } ?? ""
        return "<path d='\(pathData)'\(transformAttribute)/>"
    }
}

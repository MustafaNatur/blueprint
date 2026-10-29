import Foundation

/// The images of the paper behind a blueprint drawing: a vertical color gradient,
/// and a grid that divides the icon into 4 × 4 equal squares.
package enum BlueprintPaper {

    // MARK: - Measurements

    package static let canvasSize = 1024.0
    static let gridDivisions = 4

    // Measured from Xcode's own icon, rendered at 1024 pt with Icon Composer's ictool.

    static let gridLineWidth = 9.0
    /// The opacity of the whole grid, applied once so lines don't get brighter where they cross.
    static let gridLineOpacity = 0.25
    /// The corner radius of Icon Composer's mask, as a fraction of the canvas.
    static let maskCornerRadiusRatio = 0.26

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
    /// The other lines never meet a corner square, so they run from edge to edge.
    package static func grid() -> Data {
        let corner = GridCorner(gridLine: firstGridLine, maskCornerRadius: canvasSize * maskCornerRadiusRatio)
        let lines = innerGridLinePositions.flatMap { position in
            let meetsCorners = position == firstGridLine || position == lastGridLine
            let start = meetsCorners ? corner.gridLineStart : 0
            let end = canvasSize - start
            let vertical = gridLine(from: (position, start), to: (position, end))
            let horizontal = gridLine(from: (start, position), to: (end, position))
            return [vertical, horizontal]
        }
        let corners = CornerMirror.allCases.map { mirror in
            gridOutline(corner.pathData, transform: mirror.transform)
        }
        let strokes = (lines + corners).joined(separator: "\n")
        let width = SVG.number(gridLineWidth)
        let body = """
        <g opacity='\(gridLineOpacity)' stroke='white' stroke-width='\(width)' fill='none'>
        \(strokes)
        </g>
        """
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

    private static var lastGridLine: Double {
        canvasSize - firstGridLine
    }

    private static var innerGridLinePositions: [Double] {
        (1..<gridDivisions).map { canvasSize * Double($0) / Double(gridDivisions) }
    }

    /// The four corners of the grid, drawn by mirroring the top left one.
    private enum CornerMirror: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        /// The SVG transform that turns the top left corner into this one.
        var transform: String? {
            let size = SVG.number(canvasSize)
            switch self {
            case .topLeft: return nil
            case .topRight: return "matrix(-1 0 0 1 \(size) 0)"
            case .bottomLeft: return "matrix(1 0 0 -1 0 \(size))"
            case .bottomRight: return "matrix(-1 0 0 -1 \(size) \(size))"
            }
        }
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

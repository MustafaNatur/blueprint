import CoreGraphics

/// The outline of the grid's top left square, which follows the icon's rounded corner,
/// as in Xcode's icon.
///
/// The outline runs a little inside the edge of Icon Composer's mask and turns into the
/// grid lines with a small rounded fillet. The other three corners are its mirror images.
struct GridCorner {

    // MARK: - Measurements

    /// The corner radius of Icon Composer's mask, a continuous curve like the one
    /// `RoundedRectangle(style: .continuous)` draws.
    static let maskCornerRadius = 266.0
    /// How far inside the mask's edge the outline runs.
    static let inset = 10.0
    static let filletRadius = 34.0

    /// The position of the grid lines the outline turns into, on both axes.
    let gridLine: Double

    // MARK: - Outline

    /// Where the outline turns into the vertical grid line, measured from the top. The
    /// horizontal grid line starts at the same distance from the left.
    var gridLineStart: Double {
        fillets.top.center.y
    }

    /// The SVG path data of the outline, from the horizontal grid line, around the
    /// corner, to the vertical grid line.
    var pathData: String {
        let (left, top) = fillets
        let radius = SVG.number(Self.filletRadius)
        let corner = Self.maskCorner.map { $0.offset(by: Self.inset) }
        let curve = corner[(left.index + 1)...top.index].map(\.point)
        let curveCommands = curve.map { "L\(Self.coordinates($0))" }.joined(separator: " ")
        return [
            "M\(Self.coordinates(CGPoint(x: left.center.x, y: gridLine)))",
            "A\(radius) \(radius) 0 0 1 \(Self.coordinates(left.tangentPoint))",
            curveCommands,
            "L\(Self.coordinates(top.tangentPoint))",
            "A\(radius) \(radius) 0 0 1 \(Self.coordinates(CGPoint(x: gridLine, y: top.center.y)))",
        ].joined(separator: " ")
    }

    // MARK: - Fillets

    private struct Fillet {
        /// The index of the last point of the mask's corner before the fillet.
        var index: Int
        var center: CGPoint
        /// Where the fillet meets the curve along the corner.
        var tangentPoint: CGPoint
    }

    /// The fillets into the horizontal grid line on the left and the vertical one at the top.
    ///
    /// A fillet's center is as far from the outline as from the grid line, so it lies on
    /// the mask's edge moved inward by the inset plus the fillet's radius.
    private var fillets: (left: Fillet, top: Fillet) {
        let centers = Self.maskCorner.map { $0.offset(by: Self.inset + Self.filletRadius) }
        let centerLine = gridLine - Self.filletRadius
        let left = Self.fillet(along: centers, where: { $0.y }, crosses: centerLine)
        let top = Self.fillet(along: centers, where: { $0.x }, crosses: centerLine)
        return (left, top)
    }

    private static func fillet(along centers: [EdgePoint], where coordinate: (CGPoint) -> Double, crosses value: Double) -> Fillet {
        let index = centers.indices.dropLast().first { index in
            let start = coordinate(centers[index].point), end = coordinate(centers[index + 1].point)
            return (start - value) * (end - value) <= 0
        } ?? 0
        let start = centers[index], end = centers[index + 1]
        let startValue = coordinate(start.point), endValue = coordinate(end.point)
        let fraction = startValue == endValue ? 0 : (value - startValue) / (endValue - startValue)
        let center = start.interpolated(to: end, by: fraction)
        return Fillet(index: index, center: center.point, tangentPoint: center.offset(by: -filletRadius).point)
    }

    // MARK: - Mask

    /// A point on the mask's edge, with the direction pointing into the icon.
    private struct EdgePoint {
        var point: CGPoint
        var inward: CGVector

        func offset(by distance: Double) -> EdgePoint {
            let moved = CGPoint(x: point.x + inward.dx * distance, y: point.y + inward.dy * distance)
            return EdgePoint(point: moved, inward: inward)
        }

        func interpolated(to other: EdgePoint, by fraction: Double) -> EdgePoint {
            func mix(_ a: Double, _ b: Double) -> Double { a + (b - a) * fraction }
            let point = CGPoint(x: mix(point.x, other.point.x), y: mix(point.y, other.point.y))
            let inward = CGVector(dx: mix(inward.dx, other.inward.dx), dy: mix(inward.dy, other.inward.dy))
            return EdgePoint(point: point, inward: inward)
        }
    }

    /// The control points of the mask's top left corner in units of its corner radius,
    /// from the left edge up to the top edge, as three cubic Bézier curves.
    private static let continuousCorner: [[CGPoint]] = [
        [CGPoint(x: 0, y: 1.52866483), CGPoint(x: 0, y: 1.08849299), CGPoint(x: 0, y: 0.86840701), CGPoint(x: 0.07491100, y: 0.63149399)],
        [CGPoint(x: 0.07491100, y: 0.63149399), CGPoint(x: 0.16905899, y: 0.37282401), CGPoint(x: 0.37282392, y: 0.16905899), CGPoint(x: 0.63149399, y: 0.07491100)],
        [CGPoint(x: 0.63149399, y: 0.07491100), CGPoint(x: 0.86840689, y: 0), CGPoint(x: 1.08849323, y: 0), CGPoint(x: 1.52866483, y: 0)],
    ]

    private static let pointsPerCurve = 40

    /// Points along the mask's top left corner, from the left edge up to the top edge.
    private static let maskCorner: [EdgePoint] = continuousCorner.flatMap { unitControls in
        let controls = unitControls.map { CGPoint(x: $0.x * maskCornerRadius, y: $0.y * maskCornerRadius) }
        return (0..<pointsPerCurve).map { step in
            edgePoint(on: controls, at: Double(step) / Double(pointsPerCurve))
        }
    } + [edgePoint(on: continuousCorner[2].map { CGPoint(x: $0.x * maskCornerRadius, y: $0.y * maskCornerRadius) }, at: 1)]

    /// The point at `t` on a cubic Bézier curve, facing left of the direction of travel.
    private static func edgePoint(on controls: [CGPoint], at t: Double) -> EdgePoint {
        let (p0, p1, p2, p3) = (controls[0], controls[1], controls[2], controls[3])
        let u = 1 - t
        func point(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
        }
        func slope(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
            3 * u * u * (b - a) + 6 * u * t * (c - b) + 3 * t * t * (d - c)
        }
        let dx = slope(p0.x, p1.x, p2.x, p3.x), dy = slope(p0.y, p1.y, p2.y, p3.y)
        let length = max((dx * dx + dy * dy).squareRoot(), .ulpOfOne)
        return EdgePoint(
            point: CGPoint(x: point(p0.x, p1.x, p2.x, p3.x), y: point(p0.y, p1.y, p2.y, p3.y)),
            inward: CGVector(dx: -dy / length, dy: dx / length)
        )
    }

    private static func coordinates(_ point: CGPoint) -> String {
        "\(SVG.number(point.x)) \(SVG.number(point.y))"
    }
}

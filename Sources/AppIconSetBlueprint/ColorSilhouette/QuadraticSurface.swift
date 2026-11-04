/// A value that changes smoothly across the icon: flat, tilted, or gently curved.
///
/// Its value at a point is a sum of six terms, each scaled by its own weight:
///
///     value = w₀ + w₁·x + w₂·y + w₃·x² + w₄·x·y + w₅·y²
///
/// The first weight sets the level, the next two tilt it, and the last three bend it.
/// That's enough to follow the linear and radial gradients icons use as backgrounds.
struct QuadraticSurface {
    /// The weights of the terms, in the order of the formula above.
    var weights: [Double]

    /// A surface with the same value everywhere.
    static func flat(_ value: Double) -> QuadraticSurface {
        let weights = [value, 0, 0, 0, 0, 0]
        return QuadraticSurface(weights: weights)
    }

    func value(at point: IconPoint) -> Double {
        let x = point.x
        let y = point.y
        let level = weights[0]
        let tilt = weights[1] * x + weights[2] * y
        let bend = weights[3] * x * x + weights[4] * x * y + weights[5] * y * y
        return level + tilt + bend
    }
}

/// Finds the surfaces that come closest to values at a set of points: the ones with the
/// smallest sum of squared misses.
///
/// This is linear least squares. The best weights solve the "normal equations"
/// `(Tᵀ·T)·w = Tᵀ·v`, where each row of `T` holds the six terms at one point and `v`
/// holds the values. `Tᵀ·T` depends only on the points, so it's worked out once and
/// shared by every surface fitted through them.
struct SurfaceFitter {
    /// The six terms of the formula at each point.
    private let termsAtPoints: [[Double]]

    /// `Tᵀ·T`: for each pair of terms, the sum over the points of the two multiplied.
    private let termProducts: [[Double]]

    private static let termCount = 6

    init(points: [IconPoint]) {
        let termsAtPoints = points.map(Self.terms(at:))
        let emptyRow = [Double](repeating: 0, count: Self.termCount)
        var termProducts = [[Double]](repeating: emptyRow, count: Self.termCount)

        for terms in termsAtPoints {
            for row in 0..<Self.termCount {
                for column in 0..<Self.termCount {
                    termProducts[row][column] += terms[row] * terms[column]
                }
            }
        }

        self.termsAtPoints = termsAtPoints
        self.termProducts = termProducts
    }

    /// Returns the surface that comes closest to the values, one for each point, or nil
    /// when the points don't pin one down, such as when they all lie on one line.
    func surface(through values: [Double]) -> QuadraticSurface? {
        var termsTimesValues = [Double](repeating: 0, count: Self.termCount)
        for (terms, value) in zip(termsAtPoints, values) {
            for row in 0..<Self.termCount {
                termsTimesValues[row] += terms[row] * value
            }
        }

        guard let weights = solve(termProducts, times: termsTimesValues) else { return nil }
        return QuadraticSurface(weights: weights)
    }

    private static func terms(at point: IconPoint) -> [Double] {
        let x = point.x
        let y = point.y
        return [1, x, y, x * x, x * y, y * y]
    }
}

/// Returns the unknowns `u` that make `matrix · u` equal `results`, or nil when there's
/// no single answer.
///
/// This is Gaussian elimination. Each unknown in turn is cleared from every equation but
/// one, picking the equation where it's largest, which keeps rounding errors small. What's
/// left reads off the answer directly.
private func solve(_ matrix: [[Double]], times results: [Double]) -> [Double]? {
    let size = results.count
    var rows = matrix
    var rowResults = results
    let smallestPivot = 1e-12

    for unknown in 0..<size {
        let candidates = unknown..<size
        let magnitudes = candidates.map { row in
            let coefficient = rows[row][unknown]
            return abs(coefficient)
        }
        guard let largest = magnitudes.max(), largest > smallestPivot,
              let offset = magnitudes.firstIndex(of: largest)
        else { return nil }
        let pivotRow = unknown + offset
        rows.swapAt(unknown, pivotRow)
        rowResults.swapAt(unknown, pivotRow)

        let pivot = rows[unknown][unknown]
        for row in 0..<size where row != unknown {
            let factor = rows[row][unknown] / pivot
            for column in unknown..<size {
                rows[row][column] -= factor * rows[unknown][column]
            }
            rowResults[row] -= factor * rowResults[unknown]
        }
    }

    var unknowns: [Double] = []
    for row in 0..<size {
        let unknown = rowResults[row] / rows[row][row]
        unknowns.append(unknown)
    }
    return unknowns
}

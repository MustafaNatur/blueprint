import CoreImage

/// Finds lines wherever the color in a flat icon changes sharply, like a pencil sketch.
///
/// The threshold is relative to the icon's own strongest edges, so soft icons get lines
/// as well as high-contrast ones.
struct EdgeFinder {
    var lineWidth: Double

    private let smoothing = 2.0
    private let edgeIntensity = 3.0
    private let strongEdgePercentile = 0.995
    private let shareOfStrongEdge = 0.35
    private let weakestEdge = 0.04

    func edges(in icon: RGBAImage) throws -> AlphaMask {
        let strength = try edgeStrength(in: icon)
        let strongEdge = Double(percentile(strength.pixels, strongEdgePercentile)) / 255
        let level = max(weakestEdge, strongEdge * shareOfStrongEdge)

        let lines = strength.thresholded(at: level, softness: level / 3)
        let thickLines = try lines.grown(by: lineWidth / 2)
        return try thickLines.blurred(by: 1)
    }

    private func edgeStrength(in icon: RGBAImage) throws -> AlphaMask {
        let image = CIImage(cgImage: try icon.cgImage())
        let smoothed = image.clampedToExtent().applyingGaussianBlur(sigma: smoothing).cropped(to: image.extent)
        let edges = smoothed.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: edgeIntensity])
        let strongestChannel = edges.cropped(to: image.extent).applyingFilter("CIMaximumComponent")
        return AlphaMask.rendering(strongestChannel, width: icon.width, height: icon.height)
    }

    private func percentile(_ values: [UInt8], _ fraction: Double) -> UInt8 {
        var histogram = [Int](repeating: 0, count: 256)
        for value in values {
            histogram[Int(value)] += 1
        }
        let target = Double(values.count) * fraction
        var seen = 0
        for (value, count) in histogram.enumerated() {
            seen += count
            if Double(seen) >= target { return UInt8(value) }
        }
        return 255
    }
}

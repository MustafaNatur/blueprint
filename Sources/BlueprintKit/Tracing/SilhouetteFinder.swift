import CoreImage
import Vision

/// Finds the silhouette of the shapes in a flat icon: white where a shape is, black elsewhere.
protocol SilhouetteFinder {
    func silhouette(of icon: RGBAImage) throws -> AlphaMask
}

// MARK: - Background Color

/// Treats every pixel that clearly differs from the background as part of a shape.
///
/// The background is read from the corners: the top corners give its color at the top,
/// the bottom corners at the bottom, so vertical gradients work as well as flat colors.
struct BackgroundColorSilhouette: SilhouetteFinder {
    private let cornerSize = 24
    private let sameColor = 0.06
    private let differentColor = 0.16
    private let smallestDetail = 3.0

    func silhouette(of icon: RGBAImage) throws -> AlphaMask {
        let topColor = averageColor(of: icon, inCornersAtY: 0)
        let bottomColor = averageColor(of: icon, inCornersAtY: icon.height - cornerSize)

        let difference = AlphaMask(width: icon.width, height: icon.height) { x, y in
            let progress = Double(y) / Double(icon.height - 1)
            let background = mix(topColor, bottomColor, progress)
            let pixel = icon.color(x: x, y: y)
            return smoothStep(from: sameColor, to: differentColor, distance(pixel, background))
        }
        return try difference.cleaned(radius: smallestDetail)
    }

    private func averageColor(of icon: RGBAImage, inCornersAtY top: Int) -> RGBAImage.Color {
        var sum: RGBAImage.Color = (0, 0, 0)
        var count = 0.0
        for left in [0, icon.width - cornerSize] {
            for y in top..<(top + cornerSize) {
                for x in left..<(left + cornerSize) {
                    let color = icon.color(x: x, y: y)
                    sum = (sum.red + color.red, sum.green + color.green, sum.blue + color.blue)
                    count += 1
                }
            }
        }
        return (sum.red / count, sum.green / count, sum.blue / count)
    }

    private func mix(_ first: RGBAImage.Color, _ second: RGBAImage.Color, _ progress: Double) -> RGBAImage.Color {
        let red = first.red + (second.red - first.red) * progress
        let green = first.green + (second.green - first.green) * progress
        let blue = first.blue + (second.blue - first.blue) * progress
        return (red, green, blue)
    }

    /// The largest difference in any color channel, from 0 to 1.
    private func distance(_ first: RGBAImage.Color, _ second: RGBAImage.Color) -> Double {
        let largest = max(abs(first.red - second.red), abs(first.green - second.green), abs(first.blue - second.blue))
        return largest / 255
    }
}

// MARK: - Vision Subject

/// Uses Vision's subject lifting, the same as "Lift subject from background" in Photos.
struct SubjectSilhouette: SilhouetteFinder {
    func silhouette(of icon: RGBAImage) throws -> AlphaMask {
        let image = try icon.cgImage()
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let subjects = request.results?.first else {
            return AlphaMask(width: icon.width, height: icon.height) { _, _ in 0 }
        }
        let maskBuffer = try subjects.generateScaledMaskForImage(forInstances: subjects.allInstances, from: handler)
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        return AlphaMask.rendering(maskImage, width: icon.width, height: icon.height)
    }
}

// MARK: - Best of Both

/// Picks between the background color and Vision's subject.
///
/// The background color keeps the finest detail, so it wins whenever Vision broadly
/// agrees with it. When they disagree, the background was busy, so the background color
/// caught its texture too, and Vision's subject wins instead.
struct BestSilhouette: SilhouetteFinder {
    var byBackgroundColor: any SilhouetteFinder = BackgroundColorSilhouette()
    var bySubject: any SilhouetteFinder = SubjectSilhouette()

    /// How much the two silhouettes must overlap, from 0 to 1, to trust the background color.
    var agreementNeeded = 0.6

    func silhouette(of icon: RGBAImage) throws -> AlphaMask {
        let backgroundShapes = try byBackgroundColor.silhouette(of: icon)
        let subject = try bySubject.silhouette(of: icon)

        let agreement = backgroundShapes.overlap(with: subject)
        let trustsBackgroundColor = agreement >= agreementNeeded || subject.isEmpty
        return trustsBackgroundColor ? backgroundShapes : subject
    }
}

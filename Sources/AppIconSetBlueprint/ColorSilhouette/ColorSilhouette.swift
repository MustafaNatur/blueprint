import BlueprintCore

/// Finds the foreground of a flat icon by its colors: whatever looks different from the
/// background behind it.
///
/// It works in three steps:
///
/// 1. **Sample the edge.** The background nearly always shows along the icon's edge, so
///    the pixels there are samples of it.
/// 2. **Fit the background.** It may be one color or a gradient, so it's modeled as a
///    ``BackgroundGradient`` fitted to the samples. Shapes that run off the edge would
///    pull the fit toward their own colors, so the fit is repeated a few times, each time
///    keeping only the samples close to the last one.
/// 3. **Compare every pixel.** A pixel belongs to the foreground as much as its color
///    differs from the background's color at its spot.
struct ColorSilhouette: SilhouetteFinder {

    // MARK: - Configuration

    /// Where the band of edge samples starts, as a fraction of the icon's width.
    private let edgeInset = 0.01

    /// How thick the band of edge samples is, as a fraction of the icon's width.
    private let edgeThickness = 0.01

    /// How many times the background is fitted, each time to the samples close to the last fit.
    private let fittingRounds = 5

    /// The Oklab distance within which an edge sample always counts as background.
    private let smallestBackgroundTolerance = 0.03

    /// How far an edge sample may stray from the fit, in multiples of the typical sample's
    /// distance, and still count as background. Gradients the fit can't quite follow
    /// spread the samples out, so the tolerance grows with them.
    private let backgroundToleranceFactor = 3.0

    /// The Oklab distance from the background up to which a pixel is background.
    private let backgroundDistance = 0.05

    /// The Oklab distance from the background from which a pixel is foreground. Between
    /// the two, around anti-aliased edges, a pixel is partly both.
    private let foregroundDistance = 0.08

    // MARK: - Finding the Silhouette

    func silhouette(of icon: RGBAImage) throws -> AlphaMask {
        let picture = LabPicture(icon)
        let edgeSamples = picture.edgeSamples(inset: edgeInset, thickness: edgeThickness)
        guard !edgeSamples.isEmpty else {
            return AlphaMask(width: icon.width, height: icon.height) { _, _ in 0 }
        }

        let background = background(fittedTo: edgeSamples)
        return foreground(of: picture, against: background)
    }

    // MARK: - Fitting the Background

    /// Returns the background the edge samples show, leaving out shapes that touch the edge.
    ///
    /// The first guess is the median edge color, which shapes on the edge can't move as
    /// long as most of the edge is background. Each round then fits a gradient to the
    /// samples close to the last guess.
    private func background(fittedTo edgeSamples: [ColorSample]) -> BackgroundGradient {
        let edgeColors = edgeSamples.map(\.color)
        let medianColor = OKLabColor.median(of: edgeColors)
        var background = BackgroundGradient(solid: medianColor)

        for _ in 0..<fittingRounds {
            let backgroundSamples = samples(of: edgeSamples, closeTo: background)
            guard let closerBackground = BackgroundGradient.fitted(to: backgroundSamples) else { break }
            background = closerBackground
        }
        return background
    }

    /// Returns the samples close enough to the background to be part of it.
    private func samples(of edgeSamples: [ColorSample], closeTo background: BackgroundGradient) -> [ColorSample] {
        let distances = edgeSamples.map { sample in
            background.distance(to: sample)
        }
        let typicalDistance = distances.median
        let scaledTolerance = typicalDistance * backgroundToleranceFactor
        let tolerance = max(smallestBackgroundTolerance, scaledTolerance)

        var closeSamples: [ColorSample] = []
        for (sample, distance) in zip(edgeSamples, distances) where distance < tolerance {
            closeSamples.append(sample)
        }
        return closeSamples
    }

    // MARK: - Comparing Every Pixel

    /// Returns a mask that's white where the picture differs from the background.
    ///
    /// Pixels that aren't solid, such as the transparent margin around a macOS icon, are
    /// left out.
    private func foreground(of picture: LabPicture, against background: BackgroundGradient) -> AlphaMask {
        var pixels = [UInt8](repeating: 0, count: picture.pixelCount)

        for index in 0..<picture.pixelCount where picture.isSolid(at: index) {
            let sample = picture.sample(at: index)
            let distance = background.distance(to: sample)
            let foregroundness = smoothStep(from: backgroundDistance, to: foregroundDistance, distance)
            let maskValue = foregroundness * 255
            pixels[index] = UInt8(maskValue)
        }

        return AlphaMask(width: picture.width, height: picture.height, pixels: pixels)
    }
}

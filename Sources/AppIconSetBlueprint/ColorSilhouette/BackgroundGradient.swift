/// The color of an icon's background at every point: a single color, or a gradient that
/// changes smoothly across the icon.
///
/// Each Oklab component gets its own ``QuadraticSurface``.
struct BackgroundGradient {
    var lightness: QuadraticSurface
    var greenRed: QuadraticSurface
    var blueYellow: QuadraticSurface

    /// A background of one color.
    init(solid color: OKLabColor) {
        lightness = .flat(color.lightness)
        greenRed = .flat(color.greenRed)
        blueYellow = .flat(color.blueYellow)
    }

    private init(lightness: QuadraticSurface, greenRed: QuadraticSurface, blueYellow: QuadraticSurface) {
        self.lightness = lightness
        self.greenRed = greenRed
        self.blueYellow = blueYellow
    }

    /// Returns the gradient that comes closest to the samples' colors, or nil when the
    /// samples don't pin one down.
    static func fitted(to samples: [ColorSample]) -> BackgroundGradient? {
        let points = samples.map(\.point)
        let lightnesses = samples.map(\.color.lightness)
        let greenReds = samples.map(\.color.greenRed)
        let blueYellows = samples.map(\.color.blueYellow)

        let fitter = SurfaceFitter(points: points)
        guard let lightness = fitter.surface(through: lightnesses),
              let greenRed = fitter.surface(through: greenReds),
              let blueYellow = fitter.surface(through: blueYellows)
        else { return nil }

        return BackgroundGradient(lightness: lightness, greenRed: greenRed, blueYellow: blueYellow)
    }

    func color(at point: IconPoint) -> OKLabColor {
        let lightnessHere = lightness.value(at: point)
        let greenRedHere = greenRed.value(at: point)
        let blueYellowHere = blueYellow.value(at: point)
        return OKLabColor(lightness: lightnessHere, greenRed: greenRedHere, blueYellow: blueYellowHere)
    }

    /// Returns how different the sample looks from the background at its spot.
    func distance(to sample: ColorSample) -> Double {
        let backgroundColor = color(at: sample.point)
        return sample.color.distance(to: backgroundColor)
    }
}

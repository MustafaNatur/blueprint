import Foundation

/// A color in Oklab, a color space where the distance between two colors matches how
/// different they look to the eye.
///
/// In sRGB, the space images are stored in, the same distance can be a barely visible
/// step between two dark blues and an obvious one between two yellows. Oklab evens that
/// out, so one tolerance works for every color. Björn Ottosson designed it in 2020:
/// https://bottosson.github.io/posts/oklab/
struct OKLabColor: Equatable {
    /// How light the color is, from 0 for black to 1 for white.
    var lightness: Double

    /// How green the color is when negative, or red when positive.
    var greenRed: Double

    /// How blue the color is when negative, or yellow when positive.
    var blueYellow: Double

    init(lightness: Double, greenRed: Double, blueYellow: Double) {
        self.lightness = lightness
        self.greenRed = greenRed
        self.blueYellow = blueYellow
    }

    /// Creates the color of sRGB components from 0 to 1, as they're stored in an image.
    init(red: Double, green: Double, blue: Double) {
        let redLight = Self.light(in: red)
        let greenLight = Self.light(in: green)
        let blueLight = Self.light(in: blue)

        // How strongly the eye's long, medium and short cones respond to that light.
        let longCone = 0.4122214708 * redLight + 0.5363325363 * greenLight + 0.0514459929 * blueLight
        let mediumCone = 0.2119034982 * redLight + 0.6806995451 * greenLight + 0.1073969566 * blueLight
        let shortCone = 0.0883024619 * redLight + 0.2817188376 * greenLight + 0.6299787005 * blueLight

        // The eye notices changes in dim light more than the same changes in bright light.
        let longResponse = cbrt(longCone)
        let mediumResponse = cbrt(mediumCone)
        let shortResponse = cbrt(shortCone)

        lightness = 0.2104542553 * longResponse + 0.7936177850 * mediumResponse - 0.0040720468 * shortResponse
        greenRed = 1.9779984951 * longResponse - 2.4285922050 * mediumResponse + 0.4505937099 * shortResponse
        blueYellow = 0.0259040371 * longResponse + 0.7827717662 * mediumResponse - 0.8086757660 * shortResponse
    }

    /// Returns how different the two colors look: 0 when they're the same, and about
    /// 1 between black and white.
    func distance(to other: OKLabColor) -> Double {
        let lightnessDifference = lightness - other.lightness
        let greenRedDifference = greenRed - other.greenRed
        let blueYellowDifference = blueYellow - other.blueYellow

        let lightnessSquared = lightnessDifference * lightnessDifference
        let greenRedSquared = greenRedDifference * greenRedDifference
        let blueYellowSquared = blueYellowDifference * blueYellowDifference

        let squaredDistance = lightnessSquared + greenRedSquared + blueYellowSquared
        return squaredDistance.squareRoot()
    }

    /// Returns the color in the middle of the colors, taken one component at a time.
    ///
    /// Unlike an average, a median isn't pulled toward a few colors that stand out.
    static func median(of colors: [OKLabColor]) -> OKLabColor {
        let lightnesses = colors.map(\.lightness)
        let greenReds = colors.map(\.greenRed)
        let blueYellows = colors.map(\.blueYellow)

        let middleLightness = lightnesses.median
        let middleGreenRed = greenReds.median
        let middleBlueYellow = blueYellows.median

        return OKLabColor(lightness: middleLightness, greenRed: middleGreenRed, blueYellow: middleBlueYellow)
    }

    /// Returns the amount of light an sRGB component stands for, undoing the curve sRGB
    /// stores it with.
    private static func light(in component: Double) -> Double {
        if component <= 0.04045 {
            return component / 12.92
        }
        let shifted = (component + 0.055) / 1.055
        return pow(shifted, 2.4)
    }
}

extension [Double] {
    /// The value in the middle once the values are sorted, or 0 when there are none.
    var median: Double {
        guard !isEmpty else { return 0 }
        let sortedValues = sorted()
        let middleIndex = sortedValues.count / 2
        return sortedValues[middleIndex]
    }
}

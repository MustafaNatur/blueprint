import BlueprintCore

/// A spot on an icon, measured from its center in icon widths, so each coordinate runs
/// from -0.5 to 0.5 whatever the icon's size.
struct IconPoint {
    var x: Double
    var y: Double
}

/// A pixel's color and where it is.
struct ColorSample {
    var point: IconPoint
    var color: OKLabColor
}

/// An icon's pixels as Oklab colors, with how opaque each one is, stored top row first.
struct LabPicture {
    let width: Int
    let height: Int
    let colors: [OKLabColor]
    let opacities: [Double]

    /// How opaque a pixel must be to count. Fainter pixels are a rounded plate's soft
    /// rim or its shadow, not part of the icon's picture.
    private let solidOpacity = 0.9

    init(_ icon: RGBAImage) {
        let pixelCount = icon.width * icon.height
        var colors: [OKLabColor] = []
        var opacities: [Double] = []
        colors.reserveCapacity(pixelCount)
        opacities.reserveCapacity(pixelCount)

        for pixel in 0..<pixelCount {
            let firstByte = pixel * 4
            let redByte = icon.bytes[firstByte]
            let greenByte = icon.bytes[firstByte + 1]
            let blueByte = icon.bytes[firstByte + 2]
            let alphaByte = icon.bytes[firstByte + 3]

            let opacity = Double(alphaByte) / 255
            opacities.append(opacity)

            guard opacity > 0 else {
                let black = OKLabColor(lightness: 0, greenRed: 0, blueYellow: 0)
                colors.append(black)
                continue
            }

            // The image stores each color multiplied by its opacity, so divide it back out.
            let red = Double(redByte) / 255 / opacity
            let green = Double(greenByte) / 255 / opacity
            let blue = Double(blueByte) / 255 / opacity
            let color = OKLabColor(red: red, green: green, blue: blue)
            colors.append(color)
        }

        self.width = icon.width
        self.height = icon.height
        self.colors = colors
        self.opacities = opacities
    }

    var pixelCount: Int {
        width * height
    }

    func index(x: Int, y: Int) -> Int {
        y * width + x
    }

    func isSolid(at index: Int) -> Bool {
        opacities[index] >= solidOpacity
    }

    /// The spot at the center of the pixel.
    func point(at index: Int) -> IconPoint {
        let column = index % width
        let row = index / width
        let columnCenter = Double(column) + 0.5
        let rowCenter = Double(row) + 0.5
        let x = columnCenter / Double(width) - 0.5
        let y = rowCenter / Double(height) - 0.5
        return IconPoint(x: x, y: y)
    }

    func sample(at index: Int) -> ColorSample {
        let point = point(at: index)
        let color = colors[index]
        return ColorSample(point: point, color: color)
    }
}

// MARK: - The Edge

extension LabPicture {
    /// Returns the solid pixels in a thin band just inside the edge of the icon, where its
    /// background shows.
    ///
    /// The band follows the solid part of the image, so it works whether the icon fills its
    /// square or sits on a transparent margin with rounded corners, like a macOS icon. It
    /// starts a little way in, to skip the soft rim of a rounded plate.
    ///
    /// - Parameters:
    ///   - inset: How far inside the edge the band starts, as a fraction of the icon's width.
    ///   - thickness: How thick the band is, as a fraction of the icon's width.
    func edgeSamples(inset: Double, thickness: Double) -> [ColorSample] {
        let insetPixels = Self.pixels(inset, of: width)
        let thicknessPixels = Self.pixels(thickness, of: width)
        let depths = insetPixels..<(insetPixels + thicknessPixels)

        var samples: [ColorSample] = []
        for row in 0..<height {
            let columns = solidSpan(ofRow: row)
            let rowSamples = samplesInward(across: columns, depths: depths) { column in
                index(x: column, y: row)
            }
            samples.append(contentsOf: rowSamples)
        }
        for column in 0..<width {
            let rows = solidSpan(ofColumn: column)
            let columnSamples = samplesInward(across: rows, depths: depths) { row in
                index(x: column, y: row)
            }
            samples.append(contentsOf: columnSamples)
        }
        return samples
    }

    /// Returns the samples at each depth inward from both ends of a row or column.
    ///
    /// - Parameter indexAt: The index of the pixel at a position along the row or column.
    private func samplesInward(
        across span: ClosedRange<Int>?,
        depths: Range<Int>,
        indexAt: (Int) -> Int
    ) -> [ColorSample] {
        guard let span else { return [] }
        let spanIsWideEnough = span.count > depths.upperBound * 2
        guard spanIsWideEnough else { return [] }

        var samples: [ColorSample] = []
        for depth in depths {
            let nearPosition = span.lowerBound + depth
            let farPosition = span.upperBound - depth
            for position in [nearPosition, farPosition] {
                let index = indexAt(position)
                guard isSolid(at: index) else { continue }
                let sample = sample(at: index)
                samples.append(sample)
            }
        }
        return samples
    }

    /// The columns from the first solid pixel of the row to the last, or nil when it has none.
    private func solidSpan(ofRow row: Int) -> ClosedRange<Int>? {
        let solidColumns = (0..<width).filter { column in
            let index = index(x: column, y: row)
            return isSolid(at: index)
        }
        guard let first = solidColumns.first, let last = solidColumns.last else { return nil }
        return first...last
    }

    /// The rows from the first solid pixel of the column to the last, or nil when it has none.
    private func solidSpan(ofColumn column: Int) -> ClosedRange<Int>? {
        let solidRows = (0..<height).filter { row in
            let index = index(x: column, y: row)
            return isSolid(at: index)
        }
        guard let first = solidRows.first, let last = solidRows.last else { return nil }
        return first...last
    }

    /// Returns a fraction of a length in whole pixels, at least one.
    private static func pixels(_ fraction: Double, of length: Int) -> Int {
        let exactPixels = fraction * Double(length)
        let roundedExactPixels = exactPixels.rounded()
        let roundedPixels = Int(roundedExactPixels)
        return max(1, roundedPixels)
    }
}

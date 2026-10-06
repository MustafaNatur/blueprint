import CoreImage

/// How strongly each pixel belongs to a shape, from 0 to 255, stored top row first.
///
/// Both formats trace with masks: an `.icon` layer's silhouette comes from its image's
/// transparency, a flat icon's from Vision's subject lifting. Either way, ``outlined(width:)``
/// turns the silhouette into the white line work of the blueprint.
package struct AlphaMask {
    package let width: Int
    package let height: Int
    package let pixels: [UInt8]

    package init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Creates a mask from a value between 0 and 1 for each pixel.
    package init(width: Int, height: Int, value: (_ x: Int, _ y: Int) -> Double) {
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let clamped = min(1, max(0, value(x, y)))
                pixels[y * width + x] = UInt8(clamped * 255)
            }
        }
        self.init(width: width, height: height, pixels: pixels)
    }

    package var isEmpty: Bool {
        !pixels.contains { $0 > Self.half }
    }

    // MARK: - Outlining

    /// Returns the band along the inside edge of the shape, with the whole shape lightly tinted.
    package func outlined(width lineWidth: Double, tintOpacity: Double = 0.07) throws -> AlphaMask {
        let inside = try shrunk(by: lineWidth)
        let outlinePixels = zip(pixels, inside.pixels).map { shape, inner in
            let band = shape - min(shape, inner)
            let tint = UInt8(Double(shape) * tintOpacity)
            return max(band, tint)
        }
        return AlphaMask(width: width, height: height, pixels: outlinePixels)
    }

    // MARK: - Reshaping

    /// Returns the mask shrunk inward by the given radius, in pixels.
    package func shrunk(by radius: Double) throws -> AlphaMask {
        try filtered("CIMorphologyMinimum", radius: radius)
    }

    /// Returns the mask turned fully on above `level` and fully off below it, with a soft step between.
    package func thresholded(at level: Double, softness: Double) -> AlphaMask {
        AlphaMask(width: width, height: height) { x, y in
            let value = Double(pixels[y * width + x]) / 255
            return smoothStep(from: level - softness, to: level + softness, value)
        }
    }

    // MARK: - Core Image

    /// Returns the mask as a grayscale image, white where it covers.
    package func grayImage() throws -> CGImage {
        let data = Data(pixels) as CFData
        let gray = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(
                  width: width, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                  space: gray, bitmapInfo: bitmapInfo,
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { throw BlueprintError.imageProcessingFailed }
        return image
    }

    /// Renders a Core Image result into a mask of the given size, keeping its brightest channel.
    package static func rendering(_ image: CIImage, width: Int, height: Int) -> AlphaMask {
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        var pixels = [UInt8](repeating: 0, count: width * height)
        context.render(image, toBitmap: &pixels, rowBytes: width, bounds: bounds, format: .L8, colorSpace: nil)
        return AlphaMask(width: width, height: height, pixels: pixels)
    }

    private func filtered(_ filterName: String, radius: Double) throws -> AlphaMask {
        let gray = try grayImage()
        let input = CIImage(cgImage: gray)
        let filter = CIFilter(name: filterName, parameters: [kCIInputImageKey: input, kCIInputRadiusKey: radius])
        guard let output = filter?.outputImage else { throw BlueprintError.imageProcessingFailed }
        return Self.rendering(output, width: width, height: height)
    }

    private static let half: UInt8 = 128
}

/// Eases from 0 at `low` to 1 at `high`, without a hard step.
package func smoothStep(from low: Double, to high: Double, _ value: Double) -> Double {
    let progress = min(1, max(0, (value - low) / (high - low)))
    return progress * progress * (3 - 2 * progress)
}

extension AlphaMask {
    /// Returns a picture that's white wherever the mask covers it and transparent elsewhere.
    package func whiteImage() -> RGBAImage {
        let premultipliedWhite = pixels.flatMap { alpha in [alpha, alpha, alpha, alpha] }
        return RGBAImage(width: width, height: height, bytes: premultipliedWhite)
    }
}

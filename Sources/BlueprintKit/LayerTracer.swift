import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Redraws one layer image as a white outline of its shape.
///
/// The outline runs along the inside edge of the image's silhouette, and the shape
/// itself gets a faint white tint. The result is an SVG at the image's original
/// point size, so it drops into the layer's place unchanged.
struct LayerTracer {

    // MARK: - Configuration

    /// The outline width in the finished icon, in points.
    var lineWidth: Double

    /// The scale the layer draws its image at in the icon.
    var layerScale: Double

    private let pixelsPerPoint = 2.0
    private let tintOpacity = 0.07
    private let smallestLayerScale = 0.01

    // MARK: - Tracing

    /// Returns an SVG of the image's outline.
    ///
    /// - Parameters:
    ///   - imageData: The layer image, in any format `NSImage` reads, such as SVG or PNG.
    ///   - name: The image's file name, used in error messages.
    /// - Throws: ``BlueprintError/unreadableLayerImage(_:)`` when the data isn't an
    ///   image, or ``BlueprintError/imageProcessingFailed`` when tracing fails.
    func trace(_ imageData: Data, named name: String) throws -> Data {
        guard let image = NSImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
            throw BlueprintError.unreadableLayerImage(name)
        }
        let size = Self.pointSize(of: image)

        let pixelWidth = pixels(size.width)
        let pixelHeight = pixels(size.height)

        let silhouette = try AlphaMask(drawing: image, width: pixelWidth, height: pixelHeight)
        let inside = try silhouette.shrunk(by: lineWidthInPixels)
        let outline = silhouette.outline(around: inside, tintOpacity: tintOpacity)

        let png = try outline.whitePNG()
        let imageElement = SVG.image(png: png, width: size.width, height: size.height)
        return SVG.document(width: size.width, height: size.height, body: imageElement)
    }

    // MARK: - Measurements

    /// Returns the size Icon Composer gives an image, in points.
    ///
    /// Icon Composer places bitmaps one pixel per point, whatever resolution the file
    /// claims, so a PNG saved at 144 dpi keeps its full pixel size.
    private static func pointSize(of image: NSImage) -> CGSize {
        guard let bitmap = image.representations.first as? NSBitmapImageRep else { return image.size }
        return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    private func pixels(_ points: CGFloat) -> Int {
        Int((points * pixelsPerPoint).rounded())
    }

    /// The outline width in traced pixels: wider when the layer shrinks the image, so
    /// it comes out at ``lineWidth`` in the finished icon.
    private var lineWidthInPixels: Double {
        lineWidth * pixelsPerPoint / max(layerScale, smallestLayerScale)
    }
}

// MARK: - Alpha Mask

/// How opaque each pixel of an image is, from 0 to 255, stored top row first.
private struct AlphaMask {
    let width: Int
    let height: Int
    let pixels: [UInt8]

    /// Draws the image at the given pixel size and keeps how opaque each pixel is.
    init(drawing image: NSImage, width: Int, height: Int) throws {
        guard width > 0, height > 0 else { throw BlueprintError.imageProcessingFailed }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: sRGB,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        guard drawn else { throw BlueprintError.imageProcessingFailed }

        let alphaIndexes = stride(from: 3, to: rgba.count, by: 4)
        let alphaPixels = alphaIndexes.map { rgba[$0] }
        self.init(width: width, height: height, pixels: alphaPixels)
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    /// Returns the mask shrunk inward by the given radius, in pixels.
    func shrunk(by radius: Double) throws -> AlphaMask {
        let grayMask = try grayImage()
        let maskImage = CIImage(cgImage: grayMask)
        let shrink = CIFilter(name: "CIMorphologyMinimum", parameters: [
            kCIInputImageKey: maskImage,
            kCIInputRadiusKey: radius,
        ])
        guard let shrunkImage = shrink?.outputImage else { throw BlueprintError.imageProcessingFailed }

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var shrunkPixels = [UInt8](repeating: 0, count: width * height)
        context.render(
            shrunkImage,
            toBitmap: &shrunkPixels,
            rowBytes: width,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .L8,
            colorSpace: nil
        )
        return AlphaMask(width: width, height: height, pixels: shrunkPixels)
    }

    /// Returns the band between this shape and the smaller shape inside it, with the
    /// whole shape lightly tinted.
    func outline(around inside: AlphaMask, tintOpacity: Double) -> AlphaMask {
        let outlinePixels = zip(pixels, inside.pixels).map { shape, inner in
            let band = shape - min(shape, inner)
            let tint = UInt8(Double(shape) * tintOpacity)
            return max(band, tint)
        }
        return AlphaMask(width: width, height: height, pixels: outlinePixels)
    }

    /// Returns a PNG that's white wherever the mask covers it and transparent elsewhere.
    func whitePNG() throws -> Data {
        let premultipliedWhite = pixels.flatMap { alpha in [alpha, alpha, alpha, alpha] }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        let image = try cgImage(bytes: premultipliedWhite, bytesPerPixel: 4, space: sRGB, alpha: .premultipliedLast)

        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
            throw BlueprintError.imageProcessingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BlueprintError.imageProcessingFailed }
        return png as Data
    }

    private func grayImage() throws -> CGImage {
        let gray = CGColorSpaceCreateDeviceGray()
        return try cgImage(bytes: pixels, bytesPerPixel: 1, space: gray, alpha: .none)
    }

    private func cgImage(bytes: [UInt8], bytesPerPixel: Int, space: CGColorSpace, alpha: CGImageAlphaInfo) throws -> CGImage {
        let data = Data(bytes) as CFData
        let bitmapInfo = CGBitmapInfo(rawValue: alpha.rawValue)
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(
                  width: width, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 8 * bytesPerPixel, bytesPerRow: width * bytesPerPixel,
                  space: space, bitmapInfo: bitmapInfo,
                  provider: provider, decode: nil, shouldInterpolate: alpha != .none, intent: .defaultIntent
              ) else { throw BlueprintError.imageProcessingFailed }
        return image
    }
}

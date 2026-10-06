import AppKit
import BlueprintCore

/// Redraws one `.icon` layer image as a white outline of its shape.
///
/// The image's transparency is its silhouette. The result is an SVG at the image's
/// original point size, so it drops into the layer's place unchanged.
struct LayerTracer {

    // MARK: - Configuration

    /// The outline width in the finished icon, in points.
    var lineWidth: Double

    /// The scale the layer draws its image at in the icon.
    var layerScale: Double

    private let pixelsPerPoint = 2.0
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

        let picture = try RGBAImage(drawing: image, width: pixelWidth, height: pixelHeight)
        let outline = try picture.alpha.outlined(width: lineWidthInPixels)

        let png = try outline.whiteImage().pngData()
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

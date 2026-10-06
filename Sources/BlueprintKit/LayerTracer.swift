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

    /// The number of pixels traced per point.
    var pixelScale = 2.0

    private let tintOpacity = 0.07

    // MARK: - Tracing

    /// Returns an SVG of the image's outline.
    ///
    /// - Parameters:
    ///   - imageData: The layer image, in any format `NSImage` reads, such as SVG or PNG.
    ///   - name: The image's file name, used in error messages.
    /// - Returns: An SVG with the traced outline embedded as a PNG.
    /// - Throws: ``BlueprintError/unreadableLayerImage(_:)`` when the data isn't an
    ///   image, or ``BlueprintError/imageProcessingFailed`` when tracing fails.
    func trace(_ imageData: Data, named name: String) throws -> Data {
        guard let image = NSImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
            throw BlueprintError.unreadableLayerImage(name)
        }
        let size = Self.pointSize(of: image)
        let canvas = PixelCanvas(pointSize: size, pixelScale: pixelScale)
        let silhouette = canvas.alphaMask(of: image)
        let core = try canvas.eroded(silhouette, radius: strokePixels)

        let coverage = zip(silhouette, core).map { shape, inner in
            let outline = Double(shape &- min(shape, inner))
            let tint = Double(shape) * tintOpacity
            return UInt8(min(255, max(outline, tint)))
        }
        let png = try canvas.whitePNG(alpha: coverage)
        return svg(embedding: png, size: size)
    }

    /// Returns the size Icon Composer gives an image, in points.
    ///
    /// Icon Composer places bitmaps one pixel per point, whatever resolution the file
    /// claims, so a PNG saved at 144 dpi keeps its full pixel size.
    private static func pointSize(of image: NSImage) -> CGSize {
        guard let bitmap = image.representations.first as? NSBitmapImageRep else { return image.size }
        return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    /// The outline width in traced pixels.
    private var strokePixels: Double {
        lineWidth * pixelScale / max(layerScale, 0.01)
    }

    /// Returns an SVG of the given point size that shows the PNG stretched to fill it.
    private func svg(embedding png: Data, size: CGSize) -> Data {
        let w = Self.format(size.width), h = Self.format(size.height)
        return Data("""
        <svg width="\(w)" height="\(h)" viewBox="0 0 \(w) \(h)" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
        <image width="\(w)" height="\(h)" preserveAspectRatio="none" xlink:href="data:image/png;base64,\(png.base64EncodedString())"/>
        </svg>

        """.utf8)
    }

    private static func format(_ value: CGFloat) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.3f", Double(value))
    }
}

// MARK: - Pixel Canvas

/// A pixel grid for tracing, with masks stored as one 8-bit coverage value per
/// pixel, top row first.
private struct PixelCanvas {
    let width: Int
    let height: Int
    private let pointSize: CGSize

    init(pointSize: CGSize, pixelScale: Double) {
        self.pointSize = pointSize
        width = Int((pointSize.width * pixelScale).rounded())
        height = Int((pointSize.height * pixelScale).rounded())
    }

    /// Returns the image's coverage: how opaque each pixel is, from 0 to 255.
    func alphaMask(of image: NSImage) -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        rgba.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
            NSGraphicsContext.restoreGraphicsState()
        }
        return stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }

    /// Returns the mask shrunk inward by the given radius in pixels.
    func eroded(_ mask: [UInt8], radius: Double) throws -> [UInt8] {
        let input = CIImage(cgImage: grayImage(mask))
        let filter = CIFilter(name: "CIMorphologyMinimum", parameters: [
            kCIInputImageKey: input,
            kCIInputRadiusKey: radius,
        ])
        guard let output = filter?.outputImage else { throw BlueprintError.imageProcessingFailed }
        var result = [UInt8](repeating: 0, count: width * height)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output,
            toBitmap: &result,
            rowBytes: width,
            bounds: CGRect(x: 0, y: 0, width: width, height: height),
            format: .L8,
            colorSpace: nil
        )
        return result
    }

    /// Returns a PNG that's white wherever the mask covers it and transparent elsewhere.
    func whitePNG(alpha: [UInt8]) throws -> Data {
        let rgba = alpha.flatMap { [$0, $0, $0, $0] }
        let image = CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(rgba) as CFData)!,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )!
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw BlueprintError.imageProcessingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BlueprintError.imageProcessingFailed }
        return output as Data
    }

    private func grayImage(_ pixels: [UInt8]) -> CGImage {
        CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: CGDataProvider(data: Data(pixels) as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }
}

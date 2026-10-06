import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A picture with 8 bits per color channel and premultiplied alpha, stored top row first.
package struct RGBAImage {
    package let width: Int
    package let height: Int
    package let bytes: [UInt8]

    package init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    // MARK: - Drawing

    /// Creates a picture by running the drawing code on a blank canvas of the given size.
    package init(width: Int, height: Int, draw: (CGContext) -> Void) throws {
        guard width > 0, height > 0 else { throw BlueprintError.imageProcessingFailed }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: Self.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            draw(context)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        guard drawn else { throw BlueprintError.imageProcessingFailed }
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// Creates a picture of the image stretched to the given size.
    package init(drawing image: NSImage, width: Int, height: Int) throws {
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        try self.init(width: width, height: height) { _ in image.draw(in: frame) }
    }

    /// Returns this picture scaled to a square of the given side.
    package func resized(to side: Int) throws -> RGBAImage {
        let image = try cgImage()
        let frame = CGRect(x: 0, y: 0, width: side, height: side)
        return try RGBAImage(width: side, height: side) { context in
            context.interpolationQuality = .high
            context.draw(image, in: frame)
        }
    }

    // MARK: - Reading

    /// How opaque each pixel is.
    package var alpha: AlphaMask {
        let alphaIndexes = stride(from: 3, to: bytes.count, by: 4)
        let alphaPixels = alphaIndexes.map { bytes[$0] }
        return AlphaMask(width: width, height: height, pixels: alphaPixels)
    }

    // MARK: - Exporting

    package func cgImage() throws -> CGImage {
        let data = Data(bytes) as CFData
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(
                  width: width, height: height,
                  bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                  space: Self.sRGB, bitmapInfo: bitmapInfo,
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ) else { throw BlueprintError.imageProcessingFailed }
        return image
    }

    package func pngData() throws -> Data {
        let image = try cgImage()
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
            throw BlueprintError.imageProcessingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BlueprintError.imageProcessingFailed }
        return png as Data
    }

    package static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
}

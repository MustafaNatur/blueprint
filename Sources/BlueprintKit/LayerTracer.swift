import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

/// Redraws one icon layer as a blueprint: its silhouette becomes a white outline
/// with a faint tint and dashed center lines, at the layer's original point size.
struct LayerTracer {
    var lineWidth: Double
    var layerScale: Double
    var pixelScale = 2.0

    private let tintOpacity = 0.07
    private let centerLineOpacity = 0.45

    func trace(_ imageData: Data, named name: String) throws -> Data {
        guard let image = NSImage(data: imageData), image.size.width > 0, image.size.height > 0 else {
            throw BlueprintError.unreadableLayerImage(name)
        }
        let size = Self.pointSize(of: image)
        let canvas = PixelCanvas(pointSize: size, pixelScale: pixelScale)
        let silhouette = canvas.alphaMask(of: image)
        let core = try canvas.eroded(silhouette, radius: strokePixels)
        let centerLines = canvas.dashedCenterLines(
            within: canvas.bounds(of: silhouette, threshold: 128),
            inset: strokePixels * 3,
            width: strokePixels * 0.35,
            dash: [strokePixels * 1.4, strokePixels * 1.1]
        )

        let coverage = zip(zip(silhouette, core), centerLines).map { pair, line in
            let (shape, inner) = pair
            let outline = Double(shape &- min(shape, inner))
            let tint = Double(shape) * tintOpacity
            let center = Double(line) * Double(inner) / 255 * centerLineOpacity
            return UInt8(min(255, max(outline, tint, center)))
        }
        let png = try canvas.whitePNG(alpha: coverage)
        return svg(embedding: png, size: size)
    }

    /// Icon Composer places bitmap layers one pixel per point, whatever DPI the file
    /// claims, so a 144 dpi PNG must not shrink to half its size.
    private static func pointSize(of image: NSImage) -> CGSize {
        guard let bitmap = image.representations.first as? NSBitmapImageRep else { return image.size }
        return CGSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    private var strokePixels: Double {
        lineWidth * pixelScale / max(layerScale, 0.01)
    }

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

/// An 8-bit grayscale pixel grid used for mask arithmetic.
private struct PixelCanvas {
    let width: Int
    let height: Int
    private let pointSize: CGSize

    init(pointSize: CGSize, pixelScale: Double) {
        self.pointSize = pointSize
        width = Int((pointSize.width * pixelScale).rounded())
        height = Int((pointSize.height * pixelScale).rounded())
    }

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

    func bounds(of mask: [UInt8], threshold: UInt8) -> CGRect {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where mask[y * width + x] >= threshold {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return .null }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    func dashedCenterLines(within box: CGRect, inset: Double, width lineWidth: Double, dash: [Double]) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard !box.isNull, box.width > inset * 2, box.height > inset * 2 else { return pixels }
        let inner = box.insetBy(dx: inset, dy: inset)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )!
            // Mask rows are stored top-down; CGContext draws bottom-up.
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setStrokeColor(gray: 1, alpha: 1)
            context.setLineWidth(lineWidth)
            context.setLineDash(phase: 0, lengths: dash.map { CGFloat($0) })
            context.strokeLineSegments(between: [
                CGPoint(x: inner.midX, y: inner.minY), CGPoint(x: inner.midX, y: inner.maxY),
                CGPoint(x: inner.minX, y: inner.midY), CGPoint(x: inner.maxX, y: inner.midY),
            ])
        }
        return pixels
    }

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

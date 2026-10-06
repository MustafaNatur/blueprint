import AppIconSetBlueprint
import CoreGraphics
import Foundation
import IconKit
import ImageIO
import UniformTypeIdentifiers

/// Icons and folders the test targets share.
package enum Fixtures {

    // MARK: - Folders

    /// A new, empty folder path in the temporary directory. The caller removes it.
    package static func temporaryFolder(named extension: String = "") -> URL {
        let name = UUID().uuidString + (`extension`.isEmpty ? "" : ".\(`extension`)")
        return FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    // MARK: - Images

    /// A PNG with a filled square inset from its transparent edges, like an `.icon` layer.
    package static func layerPNG(width: Int = 200, height: Int = 200, dpi: Double = 72) throws -> Data {
        try png(width: width, height: height, dpi: dpi) { context in
            context.setFillColor(red: 1, green: 0, blue: 0.5, alpha: 1)
            context.fill(CGRect(x: 20, y: 20, width: width - 40, height: height - 40))
        }
    }

    /// A flat icon PNG: a dark square on an opaque light gray background, like an `.appiconset` image.
    package static func flatIconPNG(side: Int = 1024) throws -> Data {
        try png(width: side, height: side, dpi: 72) { context in
            context.setFillColor(gray: 0.9, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.setFillColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)
            context.fill(CGRect(x: side / 4, y: side / 4, width: side / 2, height: side / 2))
        }
    }

    private static func png(width: Int, height: Int, dpi: Double, draw: (CGContext) -> Void) throws -> Data {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FixtureError.drawingFailed }
        draw(context)

        guard let image = context.makeImage() else { throw FixtureError.drawingFailed }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else {
            throw FixtureError.drawingFailed
        }
        let resolution = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
        CGImageDestinationAddImage(destination, image, resolution)
        CGImageDestinationFinalize(destination)
        return png as Data
    }

    // MARK: - Icon Composer

    /// Writes a one-layer `.icon` bundle.
    package static func writeIcon(at url: URL, image: Data, imageName: String = "Layer.png") throws {
        let layer = IconLayer(imageName: imageName)
        let document = IconDocument(groups: [IconGroup(layers: [layer])])
        let icon = IconComposerDescriptorFile(document: document, assets: [imageName: image])
        try icon.write(to: url)
    }

    // MARK: - App Icon Sets

    /// The iOS 1024 × 1024 slot, optionally in a dark or tinted appearance.
    package static func iosSlot(appearance: String? = nil) -> AppIconSetContents.Slot {
        let appearances = appearance.map { [AppIconSetContents.Appearance(appearance: "luminosity", value: $0)] }
        return AppIconSetContents.Slot(filename: "Icon.png", idiom: "universal", platform: "ios", size: "1024x1024", appearances: appearances)
    }

    /// Writes an `.appiconset` whose slots all show the flat icon.
    package static func writeIconSet(at url: URL, slots: [AppIconSetContents.Slot], imageSide: Int = 1024) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let image = try flatIconPNG(side: imageSide)
        let fileNames = Set(slots.compactMap(\.filename))
        for fileName in fileNames {
            try image.write(to: url.appendingPathComponent(fileName))
        }
        let info = AppIconSetContents.Info(author: "xcode", version: 1)
        let contents = AppIconSetContents(images: slots, info: info)
        try contents.write(to: url)
    }

    package enum FixtureError: Error {
        case drawingFailed
    }
}

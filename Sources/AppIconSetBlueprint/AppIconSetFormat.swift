import AppKit
import BlueprintCore

/// Asset catalog `.appiconset` folders: flat icon images, redrawn by separating the
/// foreground from the background with Vision.
///
/// The blueprint keeps every slot of the original, including dark and tinted ones,
/// so it looks the same in every appearance and fits every platform the original did.
package struct AppIconSetFormat: IconFormat {
    package let fileExtension = "appiconset"

    package init() {}

    /// The author written into a blueprint's `Contents.json`, which marks it as a blueprint.
    package static let blueprintAuthor = "blueprint"

    package func blueprint(of source: URL, style: BlueprintStyle) throws -> any IconBlueprint {
        let contents = try AppIconSetContents.reading(source)
        guard let largestImage = contents.largestImage, let fileName = largestImage.filename else {
            throw BlueprintError.emptyIconSet(source.lastPathComponent)
        }

        let imageURL = source.appendingPathComponent(fileName)
        guard let image = NSImage(contentsOf: imageURL) else {
            throw BlueprintError.unreadableLayerImage(fileName)
        }

        let painter = FlatBlueprintPainter(style: style)
        let blueprintImage = try painter.blueprint(of: image)
        return AppIconSetBlueprint(image: blueprintImage, slots: contents.filledSlots)
    }

    package func isBlueprint(_ url: URL) -> Bool {
        let contents = try? AppIconSetContents.reading(url)
        return contents?.info.author == Self.blueprintAuthor
    }
}

/// An `.appiconset` blueprint, ready to be saved.
struct AppIconSetBlueprint: IconBlueprint {
    /// The blueprint at full size.
    let image: RGBAImage

    /// The original's slots, which the blueprint fills with its own images.
    let slots: [AppIconSetContents.Slot]

    let layerCount = 1

    func write(to bundleURL: URL) throws {
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        var blueprintSlots: [AppIconSetContents.Slot] = []
        var writtenSizes: Set<Int> = []
        for slot in slots {
            let fileName = "Blueprint \(slot.pixelSize).png"
            if !writtenSizes.contains(slot.pixelSize) {
                let sizedImage = try image.resized(to: slot.pixelSize)
                let png = try sizedImage.pngData()
                try png.write(to: bundleURL.appendingPathComponent(fileName))
                writtenSizes.insert(slot.pixelSize)
            }
            var blueprintSlot = slot
            blueprintSlot.filename = fileName
            blueprintSlots.append(blueprintSlot)
        }

        let info = AppIconSetContents.Info(author: AppIconSetFormat.blueprintAuthor, version: 1)
        let contents = AppIconSetContents(images: blueprintSlots, info: info)
        try contents.write(to: bundleURL)
    }
}

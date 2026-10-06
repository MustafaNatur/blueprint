import BlueprintCore
import Foundation

/// The `Contents.json` of an asset catalog `.appiconset`: which image fills which icon slot.
package struct AppIconSetContents: Codable {
    package var images: [Slot]
    package var info: Info

    /// One icon slot, such as "iOS, 1024 × 1024" or "macOS, 16 × 16 at 2x".
    package struct Slot: Codable {
        package var filename: String?
        package var idiom: String?
        package var platform: String?
        package var size: String?
        package var scale: String?
        package var role: String?
        package var subtype: String?
        package var appearances: [Appearance]?

        package init(filename: String? = nil, idiom: String? = nil, platform: String? = nil, size: String? = nil,
                     scale: String? = nil, role: String? = nil, subtype: String? = nil, appearances: [Appearance]? = nil) {
            self.filename = filename
            self.idiom = idiom
            self.platform = platform
            self.size = size
            self.scale = scale
            self.role = role
            self.subtype = subtype
            self.appearances = appearances
        }
    }

    /// A dark or tinted variant of a slot.
    package struct Appearance: Codable {
        package var appearance: String
        package var value: String

        package init(appearance: String, value: String) {
            self.appearance = appearance
            self.value = value
        }
    }

    package struct Info: Codable {
        package var author: String
        package var version: Int

        package init(author: String, version: Int) {
            self.author = author
            self.version = version
        }
    }

    package init(images: [Slot], info: Info) {
        self.images = images
        self.info = info
    }

    package static let fileName = "Contents.json"

    // MARK: - Reading and Writing

    package static func reading(_ iconSetURL: URL) throws -> AppIconSetContents {
        let contentsURL = iconSetURL.appendingPathComponent(fileName)
        let contentsData = try Data(contentsOf: contentsURL)
        return try JSONDecoder().decode(AppIconSetContents.self, from: contentsData)
    }

    package func write(to iconSetURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let contentsData = try encoder.encode(self)
        let contentsURL = iconSetURL.appendingPathComponent(Self.fileName)
        try contentsData.write(to: contentsURL)
    }

    // MARK: - Slots

    /// The slots that have an image.
    package var filledSlots: [Slot] {
        images.filter { $0.filename != nil }
    }

    /// The largest image in the default appearance, the best one to trace.
    package var largestImage: Slot? {
        let defaultSlots = filledSlots.filter { $0.appearances == nil }
        let candidates = defaultSlots.isEmpty ? filledSlots : defaultSlots
        return candidates.max { $0.pixelSize < $1.pixelSize }
    }
}

extension AppIconSetContents.Slot {
    /// The image's side in pixels: its size in points times its scale, like 16 × 2 = 32.
    package var pixelSize: Int {
        let points = size?.split(separator: "x").first.flatMap { Double($0) } ?? 1024
        let scaleFactor = scale?.dropLast().description
        let multiplier = scaleFactor.flatMap { Double($0) } ?? 1
        return Int((points * multiplier).rounded())
    }
}

import Foundation

/// The `Contents.json` of an asset catalog `.appiconset`: which image fills which icon slot.
struct AppIconSetContents: Codable {
    var images: [Slot]
    var info: Info

    /// One icon slot, such as "iOS, 1024 × 1024" or "macOS, 16 × 16 at 2x".
    struct Slot: Codable {
        var filename: String?
        var idiom: String?
        var platform: String?
        var size: String?
        var scale: String?
        var role: String?
        var subtype: String?
        var appearances: [Appearance]?
    }

    /// A dark or tinted variant of a slot.
    struct Appearance: Codable {
        var appearance: String
        var value: String
    }

    struct Info: Codable {
        var author: String
        var version: Int
    }

    static let fileName = "Contents.json"

    // MARK: - Reading and Writing

    static func reading(_ iconSetURL: URL) throws -> AppIconSetContents {
        let contentsURL = iconSetURL.appendingPathComponent(fileName)
        let contentsData = try Data(contentsOf: contentsURL)
        return try JSONDecoder().decode(AppIconSetContents.self, from: contentsData)
    }

    func write(to iconSetURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let contentsData = try encoder.encode(self)
        let contentsURL = iconSetURL.appendingPathComponent(Self.fileName)
        try contentsData.write(to: contentsURL)
    }

    // MARK: - Slots

    /// The slots that have an image.
    var filledSlots: [Slot] {
        images.filter { $0.filename != nil }
    }

    /// The largest image in the default appearance, the best one to trace.
    var largestImage: Slot? {
        let defaultSlots = filledSlots.filter { $0.appearances == nil }
        let candidates = defaultSlots.isEmpty ? filledSlots : defaultSlots
        return candidates.max { $0.pixelSize < $1.pixelSize }
    }
}

extension AppIconSetContents.Slot {
    /// The image's side in pixels: its size in points times its scale, like 16 × 2 = 32.
    var pixelSize: Int {
        let points = size?.split(separator: "x").first.flatMap { Double($0) } ?? 1024
        let scaleFactor = scale?.dropLast().description
        let multiplier = scaleFactor.flatMap { Double($0) } ?? 1
        return Int((points * multiplier).rounded())
    }
}

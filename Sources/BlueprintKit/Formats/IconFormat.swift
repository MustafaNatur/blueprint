import Foundation

/// A kind of app icon blueprint can read and redraw.
///
/// Each format knows how to read its own files and save a blueprint in the same
/// format, and the rest of blueprint works with any of them. Supporting another
/// format means adding one more type that conforms, without changing the others.
protocol IconFormat: Sendable {
    /// The file extension of icons in this format, such as `"icon"`.
    var fileExtension: String { get }

    /// Reads the icon at `source` and draws its blueprint in memory.
    func blueprint(of source: URL, style: BlueprintStyle) throws -> any IconBlueprint

    /// Returns a Boolean value that indicates whether blueprint drew the icon at `url`.
    func isBlueprint(_ url: URL) -> Bool
}

/// A blueprint drawn in memory, ready to be saved.
protocol IconBlueprint {
    /// The number of layers traced from the original icon.
    var layerCount: Int { get }

    /// Writes the blueprint as a new bundle at `bundleURL`.
    func write(to bundleURL: URL) throws
}

/// The formats blueprint supports.
enum IconFormats {
    static let all: [any IconFormat] = [IconComposerFormat(), AppIconSetFormat()]

    /// Returns the format of the icon at `url`, judged by its file extension.
    static func format(of url: URL) throws -> any IconFormat {
        let fileExtension = url.lowercasedExtension
        guard let format = all.first(where: { $0.fileExtension == fileExtension }) else {
            throw BlueprintError.unsupportedFormat(url.lastPathComponent)
        }
        return format
    }
}

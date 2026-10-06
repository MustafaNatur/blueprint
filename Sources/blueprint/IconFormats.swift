import AppIconSetBlueprint
import BlueprintCore
import Foundation
import IconComposerBlueprint

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

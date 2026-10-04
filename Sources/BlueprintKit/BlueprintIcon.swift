import Foundation
import IconKit

public enum BlueprintIcon {
    /// Reads the `.icon` at `source`, redraws it as a blueprint and writes it to
    /// `destination`, replacing an earlier blueprint there but never another icon.
    /// Returns the number of layers drawn.
    @discardableResult
    public static func generate(from source: URL, to destination: URL, style: BlueprintStyle) throws -> Int {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path), !isBlueprint(destination) {
            throw BlueprintError.wouldOverwriteIcon(destination.lastPathComponent)
        }

        let original = try IconComposerDescriptorFile.reading(source)
        let blueprint = try original.blueprint(style: style)

        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent)-\(UUID().uuidString)")
        try blueprint.write(to: staging)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
        return original.document.groups.flatMap(\.layers).count
    }

    /// Whether the `.icon` at `url` was drawn by blueprint.
    public static func isBlueprint(_ url: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: url.appendingPathComponent("Assets").appendingPathComponent(IconComposerDescriptorFile.paperAssetName).path
        )
    }
}

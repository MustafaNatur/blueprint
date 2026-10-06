import Foundation
import IconKit

public enum BlueprintIcon {
    /// Reads the `.icon` at `source`, redraws it as a blueprint and writes it to
    /// `destination`, replacing an earlier blueprint there but never another icon.
    /// Returns the number of layers drawn.
    @discardableResult
    public static func generate(from source: URL, to destination: URL, style: BlueprintStyle) throws -> Int {
        let fileManager = FileManager.default
        if isBlueprint(source) {
            throw BlueprintError.alreadyBlueprint(source.lastPathComponent)
        }
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

    /// Whether the `.icon` at `url` was drawn by blueprint: it has the paper group,
    /// or, from blueprint 1.0.0, the single paper image.
    public static func isBlueprint(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.appendingPathComponent("Assets/Blueprint Paper.svg").path) {
            return true
        }
        guard let data = FileManager.default.contents(atPath: url.appendingPathComponent("icon.json").path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["groups"] as? [[String: Any]] else { return false }
        return groups.contains { $0["name"] as? String == IconComposerDescriptorFile.paperGroupName }
    }
}

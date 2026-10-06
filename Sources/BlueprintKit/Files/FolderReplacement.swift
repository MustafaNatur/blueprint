import Foundation

/// Replaces a folder, such as an `.icon` or `.appiconset` bundle, only once its new
/// contents are completely written.
enum FolderReplacement {

    /// Writes new contents into a hidden folder next to `destination`, then moves it into place.
    ///
    /// A failed write leaves `destination` as it was, and the hidden folder is always removed.
    ///
    /// - Parameters:
    ///   - destination: The folder to create or replace.
    ///   - write: Writes the new contents into the folder it's given.
    static func replace(_ destination: URL, writing write: (URL) throws -> Void) throws {
        let fileManager = FileManager.default
        let parentFolder = destination.deletingLastPathComponent()
        let stagingName = ".\(destination.lastPathComponent)-\(UUID().uuidString)"
        let staging = parentFolder.appendingPathComponent(stagingName)
        defer { try? fileManager.removeItem(at: staging) }

        try write(staging)

        let destinationIsTaken = fileManager.fileExists(atPath: destination.path)
        if destinationIsTaken {
            _ = try fileManager.replaceItemAt(destination, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: destination)
        }
    }
}

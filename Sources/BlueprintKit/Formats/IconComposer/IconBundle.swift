import Foundation

/// The names of the files inside an Icon Composer `.icon` bundle.
enum IconBundle {
    static let descriptorFileName = "icon.json"
    static let assetsFolderName = "Assets"

    static func descriptorURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(descriptorFileName)
    }

    static func assetsURL(in bundleURL: URL) -> URL {
        bundleURL.appendingPathComponent(assetsFolderName)
    }
}

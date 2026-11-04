import BlueprintCore

/// Finds the foreground of a flat icon: white where the foreground is, black over the background.
protocol SilhouetteFinder {
    func silhouette(of icon: RGBAImage) throws -> AlphaMask
}

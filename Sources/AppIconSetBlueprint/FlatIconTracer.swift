import BlueprintCore

/// Redraws a flat icon image as white line work: the outline of its foreground.
///
/// Vision's mask is computed at a lower resolution and scaled up, so its edge is soft.
/// It's firmed up before outlining, so the outline comes out as crisp as an `.icon`
/// layer's.
struct FlatIconTracer {
    var lineWidth: Double
    var silhouetteFinder: any SilhouetteFinder = SubjectSilhouette()

    private let edgeLevel = 0.5
    private let edgeSoftness = 0.1

    /// - Throws: ``BlueprintError/noForeground`` when nothing stands out from the background.
    func lineArt(of icon: RGBAImage) throws -> AlphaMask {
        let silhouette = try silhouetteFinder.silhouette(of: icon)
        guard !silhouette.isEmpty else { throw BlueprintError.noForeground }

        let firmSilhouette = silhouette.thresholded(at: edgeLevel, softness: edgeSoftness)
        return try firmSilhouette.outlined(width: lineWidth)
    }
}

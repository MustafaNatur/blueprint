/// Redraws a flat icon image as white line work: the outline of its shapes, plus the
/// edges inside them.
///
/// The outline comes from the silhouette. Edges add the detail a silhouette loses, like
/// overlapping shapes and holes, but only inside the shapes, so background texture is
/// left out.
struct FlatIconTracer {
    var lineWidth: Double
    var silhouetteFinder: any SilhouetteFinder = BestSilhouette()

    private let innerLineShare = 0.6
    private let innerMargin = 1.5

    func lineArt(of icon: RGBAImage) throws -> AlphaMask {
        let silhouette = try silhouetteFinder.silhouette(of: icon)
        let outline = try silhouette.outlined(width: lineWidth)

        let edgeFinder = EdgeFinder(lineWidth: lineWidth * innerLineShare)
        let edges = try edgeFinder.edges(in: icon)
        let insideShapes = try silhouette.shrunk(by: lineWidth * innerMargin)
        let innerEdges = edges.intersected(with: insideShapes)

        return outline.combined(with: innerEdges)
    }
}

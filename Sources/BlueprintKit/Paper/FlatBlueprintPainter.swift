import AppKit

/// Paints the blueprint of a flat icon: the paper, with the icon's line work in white on top.
///
/// The paper is drawn from the same SVG images an `.icon` blueprint uses, so both formats
/// look alike.
struct FlatBlueprintPainter {
    var style: BlueprintStyle
    var tracer: FlatIconTracer

    /// Creates a painter for the style, tracing with `tracer`, or by default with the
    /// style's line width and the best silhouette of background color and Vision.
    init(style: BlueprintStyle, tracer: FlatIconTracer? = nil) {
        self.style = style
        self.tracer = tracer ?? FlatIconTracer(lineWidth: style.lineWidth)
    }

    private let size = Int(BlueprintPaper.canvasSize)

    /// Returns the blueprint of the image at full icon size.
    func blueprint(of image: NSImage) throws -> RGBAImage {
        let icon = try RGBAImage(drawing: image, width: size, height: size)
        let lineArt = try tracer.lineArt(of: icon)
        let paper = try paperImages()
        let lineImage = try lineArt.whiteImage().cgImage()

        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        return try RGBAImage(width: size, height: size) { context in
            for sheet in paper {
                sheet.draw(in: frame)
            }
            context.draw(lineImage, in: frame)
        }
    }

    /// The background, then the grid if the style shows one, ready to draw.
    private func paperImages() throws -> [NSImage] {
        let background = BlueprintPaper.background(colors: style.backgroundColors)
        let grid = style.showsGrid ? BlueprintPaper.grid() : nil
        let svgs = [background] + (grid.map { [$0] } ?? [])
        return try svgs.map { svg in
            guard let image = NSImage(data: svg) else { throw BlueprintError.imageProcessingFailed }
            return image
        }
    }
}

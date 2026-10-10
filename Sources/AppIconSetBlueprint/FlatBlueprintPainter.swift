import AppKit
import BlueprintCore

/// Paints the blueprint of a flat icon: the paper, with the icon's line work in white on
/// top, and the badge over everything if the style has one.
///
/// The paper is drawn from the same SVG images an `.icon` blueprint uses, so both formats
/// look alike.
struct FlatBlueprintPainter {
    var style: BlueprintStyle
    var tracer: FlatIconTracer

    /// Creates a painter for the style, tracing with `tracer`, or by default with the
    /// style's line width and Vision's subject lifting.
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
        let overlays = try [lineArt.whiteImage().cgImage()] + badgeImages()

        let frame = CGRect(x: 0, y: 0, width: size, height: size)
        return try RGBAImage(width: size, height: size) { context in
            for sheet in paper {
                sheet.draw(in: frame)
            }
            for overlay in overlays {
                context.draw(overlay, in: frame)
            }
        }
    }

    /// The badge if the style has one, ready to draw.
    private func badgeImages() throws -> [CGImage] {
        guard let badgePainter = BadgePainter(style: style) else { return [] }
        return [try badgePainter.image(side: size).cgImage()]
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

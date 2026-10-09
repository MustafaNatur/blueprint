import AppKit

/// Paints a badge: its text in bold on white, framed by a border, both in the style's
/// bottom background color so the badge matches the blueprint.
///
/// The badge is painted on a transparent square the size of the whole icon, so every
/// format lays it over the blueprint without moving it.
package struct BadgePainter {
    package let badge: BlueprintBadge

    /// The color of the text and the border, as a `#RRGGBB` hex string.
    package let color: String

    /// Creates a painter for the style's badge, or returns `nil` when the style has none.
    package init?(style: BlueprintStyle) {
        guard let badge = style.badge else { return nil }
        self.badge = badge
        self.color = style.bottomBackgroundColor
    }

    private static let pixelsPerPoint = 2.0
    private static let borderWidth: CGFloat = 8

    // MARK: - Images

    /// Returns the badge on a transparent square of the given side, in pixels.
    package func image(side: Int) throws -> RGBAImage {
        let scale = Double(side) / BlueprintPaper.canvasSize
        return try RGBAImage(width: side, height: side) { context in
            context.scaleBy(x: scale, y: scale)
            draw()
        }
    }

    /// Returns an SVG of the badge, the size of the whole icon.
    package func svg() throws -> Data {
        let size = BlueprintPaper.canvasSize
        let pixelSide = Int(size * Self.pixelsPerPoint)
        let png = try image(side: pixelSide).pngData()
        let imageElement = SVG.image(png: png, width: size, height: size)
        return SVG.document(width: size, height: size, body: imageElement)
    }

    // MARK: - Drawing

    /// Draws the badge in icon points, into the current graphics context.
    private func draw() {
        let layout = BadgeLayout { fontSize, maxWidth in
            text(fontSize: fontSize).wrappedSize(maxWidth: maxWidth)
        }
        drawBackground(of: layout)
        text(fontSize: layout.fontSize).draw(with: layout.textFrame, options: NSAttributedString.wrappingOptions)
    }

    /// Draws the white background and its border, inside the layout's frame.
    private func drawBackground(of layout: BadgeLayout) {
        let inset = Self.borderWidth / 2
        let backgroundFrame = layout.frame.insetBy(dx: inset, dy: inset)
        let radius = layout.cornerRadius - inset
        let background = NSBezierPath(roundedRect: backgroundFrame, xRadius: radius, yRadius: radius)
        background.lineWidth = Self.borderWidth

        NSColor.white.setFill()
        background.fill()
        nsColor.setStroke()
        background.stroke()
    }

    /// The badge's text in bold, each line centered.
    private func text(fontSize: CGFloat) -> NSAttributedString {
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: nsColor,
            .paragraphStyle: centered,
        ]
        return NSAttributedString(string: badge.text, attributes: attributes)
    }

    /// The badge color, from the `#RRGGBB` hex string ``BlueprintStyle`` has already checked.
    private var nsColor: NSColor {
        let value = Int(color.dropFirst(), radix: 16) ?? 0
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

private extension NSAttributedString {
    /// The options that wrap text into lines, the same for measuring and drawing.
    static let wrappingOptions: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]

    /// The size the text takes up when wrapped to lines no wider than `maxWidth`, rounded up to whole points.
    func wrappedSize(maxWidth: CGFloat) -> CGSize {
        let bounds = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        let size = boundingRect(with: bounds, options: Self.wrappingOptions).size
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }
}

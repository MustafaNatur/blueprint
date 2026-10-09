import CoreGraphics

/// Where a badge sits on the icon and how large its text is, in icon points with the
/// origin at the bottom left.
///
/// The badge is anchored to the bottom right corner, inside the rounded corners of the
/// icon's mask. It grows to the left to fit its text, then wraps the text and grows
/// upward line by line. Only once it fills the icon does the text get smaller.
package struct BadgeLayout {

    // MARK: - Measurements

    static let singleLineHeight: CGFloat = 184
    static let fullFontSize: CGFloat = 112
    static let smallestFontSize: CGFloat = 8
    static let shrinkStep: CGFloat = 0.9
    static let horizontalPadding: CGFloat = 56
    static let verticalPadding: CGFloat = 24
    static let rightEdge: CGFloat = 944
    static let leftLimit: CGFloat = 80
    static let bottomEdge: CGFloat = 160
    static let topLimit: CGFloat = 944

    static var widestText: CGFloat {
        rightEdge - leftLimit - 2 * horizontalPadding
    }

    static var tallestText: CGFloat {
        topLimit - bottomEdge - 2 * verticalPadding
    }

    // MARK: - Layout

    /// Measures the text wrapped to a width: given a font size and the widest a line
    /// may be, returns the size the wrapped text takes up.
    package typealias TextMeasure = (_ fontSize: CGFloat, _ maxWidth: CGFloat) -> CGSize

    /// The rounded rectangle around the text: a capsule while the text fits on one line.
    package let frame: CGRect

    /// Where the wrapped text goes: in the middle of ``frame``.
    package let textFrame: CGRect

    /// The radius of the frame's corners.
    package let cornerRadius = singleLineHeight / 2

    /// The size of the text, in points.
    package let fontSize: CGFloat

    /// Lays out a badge whose text `measure` measures.
    package init(measure: TextMeasure) {
        fontSize = Self.largestFittingFontSize(measure: measure)
        let textSize = measure(fontSize, Self.widestText)
        let width = max(Self.singleLineHeight, textSize.width + 2 * Self.horizontalPadding)
        let height = max(Self.singleLineHeight, textSize.height + 2 * Self.verticalPadding)
        frame = CGRect(x: Self.rightEdge - width, y: Self.bottomEdge, width: width, height: height)
        let textOrigin = CGPoint(x: frame.midX - textSize.width / 2, y: frame.midY - textSize.height / 2)
        textFrame = CGRect(origin: textOrigin, size: textSize)
    }

    /// The largest font size, up to ``fullFontSize``, whose wrapped text fits the icon.
    private static func largestFittingFontSize(measure: TextMeasure) -> CGFloat {
        var fontSize = fullFontSize
        while measure(fontSize, widestText).height > tallestText, fontSize > smallestFontSize {
            fontSize = max(smallestFontSize, fontSize * shrinkStep)
        }
        return fontSize
    }
}

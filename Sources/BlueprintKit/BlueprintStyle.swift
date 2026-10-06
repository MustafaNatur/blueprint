import IconKit

/// The look of a blueprint: its background colors, outline width and grid.
///
/// The default style matches Xcode's icon: a bright blue gradient with a white
/// 4 × 4 grid and 9-point outlines.
///
/// ```swift
/// let xcodeLike = try BlueprintStyle()
/// let flatNavy = try BlueprintStyle(backgroundColors: ["#1254B3"], lineWidth: 12, showsGrid: false)
/// ```
public struct BlueprintStyle: Sendable {

    // MARK: - Inspecting a Style

    /// The background colors from top to bottom, as `#RRGGBB` hex strings.
    ///
    /// One color gives a flat background; two or more blend into a vertical gradient.
    public let backgroundColors: [String]

    /// The width of the outlines, in icon points, where the whole icon is 1024 points wide.
    public var lineWidth: Double

    /// A Boolean value that indicates whether the background shows a grid.
    public var showsGrid: Bool

    /// The middle background color, which Icon Composer uses as the icon's own fill.
    let middleBackgroundColor: IconColor

    // MARK: - Creating a Style

    /// The background colors of Xcode's icon, from bright cyan at the top to deeper blue at the bottom.
    public static let xcodeBackgroundColors = ["#0AC2FC", "#10A3FA", "#1A6FFB"]

    /// Creates a style with the background colors, outline width and grid you specify.
    ///
    /// - Parameters:
    ///   - backgroundColors: The background colors from top to bottom, as hex strings
    ///     with or without a leading `#`. Defaults to ``xcodeBackgroundColors``.
    ///   - lineWidth: The outline width in icon points. Defaults to `9`.
    ///   - showsGrid: Whether the background shows a grid. Defaults to `true`.
    /// - Throws: `HexColorError` when `backgroundColors` is empty or holds a color
    ///   that isn't a valid hex string.
    public init(backgroundColors: [String] = Self.xcodeBackgroundColors, lineWidth: Double = 9, showsGrid: Bool = true) throws {
        guard !backgroundColors.isEmpty else { throw HexColorError.invalidFormat("") }
        let parsedColors = try backgroundColors.map(parseHexIconColor)

        self.backgroundColors = backgroundColors.map { $0.hasPrefix("#") ? $0 : "#" + $0 }
        self.middleBackgroundColor = parsedColors[parsedColors.count / 2]
        self.lineWidth = lineWidth
        self.showsGrid = showsGrid
    }
}

import IconKit

/// The look of a blueprint: its paper colors, outline width and grid.
///
/// The default style matches Xcode's icon: a bright blue gradient with a white
/// 4 × 4 grid and 9-point outlines.
///
/// ```swift
/// let xcodeLike = try BlueprintStyle()
/// let flatNavy = try BlueprintStyle(paperHexes: ["#1254B3"], lineWidth: 12, showsGrid: false)
/// ```
public struct BlueprintStyle: Sendable {

    // MARK: - Inspecting a Style

    /// The paper colors from top to bottom, as `#RRGGBB` hex strings.
    ///
    /// A single color gives flat paper; two or more blend into a vertical gradient.
    public var paperHexes: [String]

    /// The width of the outlines, in icon points, where the whole icon is 1024 points wide.
    public var lineWidth: Double

    /// A Boolean value that indicates whether the paper shows a grid.
    public var showsGrid: Bool

    // MARK: - Creating a Style

    /// The paper colors of Xcode's icon, from bright cyan at the top to deeper blue at the bottom.
    public static let xcodePaper = ["#0AC2FC", "#10A3FA", "#1A6FFB"]

    /// Creates a style with the paper colors, outline width and grid you specify.
    ///
    /// - Parameters:
    ///   - paperHexes: The paper colors from top to bottom, as hex strings with or
    ///     without a leading `#`. Defaults to ``xcodePaper``.
    ///   - lineWidth: The outline width in icon points. Defaults to `9`.
    ///   - showsGrid: Whether the paper shows a grid. Defaults to `true`.
    /// - Throws: `HexColorError` when `paperHexes` is empty or holds a color that
    ///   isn't a valid hex string.
    public init(paperHexes: [String] = BlueprintStyle.xcodePaper, lineWidth: Double = 9, showsGrid: Bool = true) throws {
        guard !paperHexes.isEmpty else { throw HexColorError.invalidFormat("") }
        _ = try paperHexes.map(parseHexIconColor)
        self.paperHexes = paperHexes.map { $0.hasPrefix("#") ? $0 : "#" + $0 }
        self.lineWidth = lineWidth
        self.showsGrid = showsGrid
    }

    // MARK: - Icon Composer Values

    /// The icon's base fill, the middle paper color, which shows wherever the paper layer doesn't.
    var baseFill: IconColor {
        try! parseHexIconColor(paperHexes[paperHexes.count / 2])
    }
}

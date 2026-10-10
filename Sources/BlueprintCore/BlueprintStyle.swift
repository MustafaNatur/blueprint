import Foundation

/// The look of a blueprint: its background colors, outline width, grid and badge.
///
/// The default style matches Xcode's icon: a bright blue gradient with a white
/// 4 × 4 grid and 9-point outlines.
///
/// ```swift
/// let xcodeLike = try BlueprintStyle()
/// let flatNavy = try BlueprintStyle(backgroundColors: ["#1254B3"], lineWidth: 12, showsGrid: false)
/// let staging = try BlueprintStyle(badge: BlueprintBadge(text: "STAGING"))
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

    /// The label drawn in the bottom right corner, or `nil` for no badge.
    ///
    /// The badge's text and border take the last background color, so the badge matches
    /// the blueprint whatever its colors.
    public var badge: BlueprintBadge?

    // MARK: - Creating a Style

    /// The background colors of Xcode's icon, from bright cyan at the top to deeper blue at the bottom.
    public static let xcodeBackgroundColors = ["#0AC2FC", "#10A3FA", "#1A6FFB"]

    /// Creates a style with the background colors, outline width, grid and badge you specify.
    ///
    /// - Parameters:
    ///   - backgroundColors: The background colors from top to bottom, as hex strings
    ///     with or without a leading `#`. Defaults to ``xcodeBackgroundColors``.
    ///   - lineWidth: The outline width in icon points. Defaults to `9`.
    ///   - showsGrid: Whether the background shows a grid. Defaults to `true`.
    ///   - badge: The label drawn in the bottom right corner. Defaults to no badge.
    /// - Throws: ``BlueprintError/invalidColor(_:)`` when `backgroundColors` is empty or
    ///   holds a color that isn't a `#RRGGBB` hex string.
    public init(backgroundColors: [String] = Self.xcodeBackgroundColors, lineWidth: Double = 9, showsGrid: Bool = true,
                badge: BlueprintBadge? = nil) throws {
        guard !backgroundColors.isEmpty else { throw BlueprintError.invalidColor("") }
        let hexColors = backgroundColors.map { $0.hasPrefix("#") ? $0 : "#" + $0 }
        if let invalidColor = hexColors.first(where: { !Self.isHexColor($0) }) {
            throw BlueprintError.invalidColor(invalidColor)
        }

        self.backgroundColors = hexColors
        self.lineWidth = lineWidth
        self.showsGrid = showsGrid
        self.badge = badge
    }

    /// The middle background color, which a format can use as the icon's own fill.
    package var middleBackgroundColor: String {
        backgroundColors[backgroundColors.count / 2]
    }

    /// The bottom background color, the deepest one, which a badge is drawn in.
    package var bottomBackgroundColor: String {
        backgroundColors[backgroundColors.count - 1]
    }

    /// Whether the text is `#` followed by six hex digits.
    private static func isHexColor(_ text: String) -> Bool {
        let digits = text.dropFirst()
        return digits.count == 6 && digits.allSatisfy(\.isHexDigit)
    }
}

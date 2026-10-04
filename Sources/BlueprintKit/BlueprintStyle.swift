import IconKit

public struct BlueprintStyle: Sendable {
    /// Paper colors from top to bottom; one color gives flat paper.
    public var paperHexes: [String]
    public var lineWidth: Double
    public var showsGrid: Bool

    /// Sampled from the Xcode icon: bright cyan at the top, deeper blue at the bottom.
    public static let xcodePaper = ["#0AC2FC", "#10A3FA", "#1A6FFB"]

    public init(paperHexes: [String] = BlueprintStyle.xcodePaper, lineWidth: Double = 9, showsGrid: Bool = true) throws {
        guard !paperHexes.isEmpty else { throw HexColorError.invalidFormat("") }
        _ = try paperHexes.map(parseHexIconColor)
        self.paperHexes = paperHexes.map { $0.hasPrefix("#") ? $0 : "#" + $0 }
        self.lineWidth = lineWidth
        self.showsGrid = showsGrid
    }

    /// The icon's base fill; the paper layer paints over it.
    var baseFill: IconColor {
        try! parseHexIconColor(paperHexes[paperHexes.count / 2])
    }
}

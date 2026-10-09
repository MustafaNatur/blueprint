import Foundation

/// A label drawn on a blueprint, such as `DEV`, `UAT` or `BETA`, to tell builds for
/// different environments apart.
///
/// The text is drawn as given, on white in the bottom right corner of the icon.
/// Longer text wraps onto more lines and the badge grows upward; line breaks in the text
/// are kept.
///
/// ```swift
/// let style = try BlueprintStyle(badge: BlueprintBadge(text: "UAT"))
/// ```
public struct BlueprintBadge: Sendable, Equatable {

    /// The text of the badge, without leading or trailing spaces and line breaks.
    public let text: String

    /// Creates a badge with the text you specify.
    ///
    /// - Parameter text: The text of the badge. Leading and trailing spaces and line
    ///   breaks are removed.
    /// - Throws: ``BlueprintError/emptyBadge`` when there's no text left.
    public init(text: String) throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw BlueprintError.emptyBadge }
        self.text = trimmedText
    }
}

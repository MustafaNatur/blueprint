import Foundation
import Testing
@testable import BlueprintCore

/// Tests the pieces every format shares.
@Suite struct BlueprintCoreTests {

    // MARK: - Style

    @Test func styleAddsTheHashToColors() throws {
        let style = try BlueprintStyle(backgroundColors: ["0AC2FC", "#1A6FFB"])
        #expect(style.backgroundColors == ["#0AC2FC", "#1A6FFB"])
    }

    @Test func styleRefusesColorsThatArentHex() {
        #expect(throws: BlueprintError.invalidColor("#nothex")) {
            try BlueprintStyle(backgroundColors: ["nothex"])
        }
        #expect(throws: BlueprintError.invalidColor("")) {
            try BlueprintStyle(backgroundColors: [])
        }
    }

    @Test func middleBackgroundColorIsTheCenterOfTheGradient() throws {
        let style = try BlueprintStyle()
        #expect(style.middleBackgroundColor == "#10A3FA")
    }

    @Test func styleHasNoBadgeByDefault() throws {
        let style = try BlueprintStyle()
        #expect(style.badge == nil)
        #expect(BadgePainter(style: style) == nil)
    }

    // MARK: - Badge

    @Test func badgeTrimsSpacesAndLineBreaks() throws {
        let badge = try BlueprintBadge(text: "  UAT \n")
        #expect(badge.text == "UAT")
    }

    @Test(arguments: ["", "   ", "\n\n"])
    func badgeRefusesEmptyText(_ text: String) {
        #expect(throws: BlueprintError.emptyBadge) {
            try BlueprintBadge(text: text)
        }
    }

    @Test func badgeTakesLongAndMultilineText() throws {
        let longText = String(repeating: "RELEASE CANDIDATE ", count: 10)
        #expect(try BlueprintBadge(text: longText).text.count > 100)
        #expect(try BlueprintBadge(text: "UAT\nv2.4").text == "UAT\nv2.4")
    }

    /// Measures text as `characterCount` letters, each 0.5 em wide, wrapped into lines 1.2 em tall.
    private func measure(characterCount: Int) -> BadgeLayout.TextMeasure {
        { fontSize, maxWidth in
            let letterWidth = fontSize / 2
            let lettersPerLine = max(1, Int(maxWidth / letterWidth))
            let lineCount = (characterCount + lettersPerLine - 1) / lettersPerLine
            let longestLine = min(characterCount, lettersPerLine)
            return CGSize(width: CGFloat(longestLine) * letterWidth, height: CGFloat(lineCount) * fontSize * 1.2)
        }
    }

    @Test func shortBadgeIsACapsuleInTheBottomRightCorner() {
        let layout = BadgeLayout(measure: measure(characterCount: 3))

        #expect(layout.fontSize == BadgeLayout.fullFontSize)
        #expect(layout.frame.maxX == BadgeLayout.rightEdge)
        #expect(layout.frame.minY == BadgeLayout.bottomEdge)
        #expect(layout.frame.height == BadgeLayout.singleLineHeight)
        #expect(layout.cornerRadius == layout.frame.height / 2)
    }

    @Test func textIsInTheMiddleOfTheBadge() {
        let layout = BadgeLayout(measure: measure(characterCount: 30))

        #expect(layout.textFrame.midX == layout.frame.midX)
        #expect(layout.textFrame.midY == layout.frame.midY)
        #expect(layout.frame.contains(layout.textFrame))
    }

    @Test func narrowBadgeIsAtLeastACircle() {
        let layout = BadgeLayout(measure: measure(characterCount: 1))
        #expect(layout.frame.width == layout.frame.height)
    }

    @Test func longBadgeWrapsAndGrowsUpwardAtFullSize() {
        let lettersPerLine = Int(BadgeLayout.widestText / (BadgeLayout.fullFontSize / 2))

        let layout = BadgeLayout(measure: measure(characterCount: 2 * lettersPerLine))

        #expect(layout.fontSize == BadgeLayout.fullFontSize)
        #expect(layout.frame.minY == BadgeLayout.bottomEdge)
        #expect(layout.frame.height > BadgeLayout.singleLineHeight)
        #expect(layout.frame.minX >= BadgeLayout.leftLimit)
    }

    @Test func badgeTooLongForTheIconShrinksItsTextToFit() {
        let layout = BadgeLayout(measure: measure(characterCount: 500))

        #expect(layout.fontSize < BadgeLayout.fullFontSize)
        #expect(layout.frame.minX >= BadgeLayout.leftLimit)
        #expect(layout.frame.maxY <= BadgeLayout.topLimit)
    }

    @Test func endlessTextStopsShrinkingAtTheSmallestFontSize() {
        let layout = BadgeLayout(measure: measure(characterCount: 1_000_000))
        #expect(layout.fontSize == BadgeLayout.smallestFontSize)
    }

    private func painter(text: String) throws -> BadgePainter {
        let style = try BlueprintStyle(badge: BlueprintBadge(text: text))
        return try #require(BadgePainter(style: style))
    }

    @Test func badgeIsDrawnInTheBottomBackgroundColor() throws {
        #expect(try painter(text: "DEV").color == "#1A6FFB")
    }

    @Test func badgeImageIsWhiteInsideTheBadgeAndClearOutside() throws {
        let image = try painter(text: "DEV").image(side: 1024)

        let besideTheText = rgba(of: image, x: Int(BadgeLayout.rightEdge) - 24, y: 1024 - Int(BadgeLayout.bottomEdge) - 92)
        let topLeft = rgba(of: image, x: 100, y: 100)
        #expect(besideTheText == [255, 255, 255, 255])
        #expect(topLeft == [0, 0, 0, 0])
    }

    @Test func badgeSVGCoversTheWholeIcon() throws {
        let svg = String(decoding: try painter(text: "DEV").svg(), as: UTF8.self)
        #expect(svg.hasPrefix("<svg width='1024' height='1024'"))
    }

    /// The red, green, blue and alpha of a pixel, counted from the top left.
    private func rgba(of image: RGBAImage, x: Int, y: Int) -> [UInt8] {
        let start = (y * image.width + x) * 4
        return Array(image.bytes[start..<start + 4])
    }

    // MARK: - Paper

    @Test func gridHasFourByFourSquares() {
        let grid = String(decoding: BlueprintPaper.grid(), as: UTF8.self)
        let lineCount = grid.components(separatedBy: "<line ").count - 1
        let linesForFourSquaresEachWay = 2 * 5
        #expect(lineCount == linesForFourSquaresEachWay)
    }

    @Test func backgroundIsAGradientOfTheColors() {
        let background = String(decoding: BlueprintPaper.background(colors: ["#000000", "#FFFFFF"]), as: UTF8.self)
        #expect(background.contains("<stop offset='0.0' stop-color='#000000'/>"))
        #expect(background.contains("<stop offset='1.0' stop-color='#FFFFFF'/>"))
    }

    @Test func svgNumbersDropNeedlessDecimals() {
        #expect(SVG.number(1024) == "1024")
        #expect(SVG.number(326.5) == "326.500")
    }

    // MARK: - Masks

    @Test func outlineIsTheBandAlongTheInsideEdge() throws {
        let square = AlphaMask(width: 64, height: 64) { x, y in
            (16..<48).contains(x) && (16..<48).contains(y) ? 1 : 0
        }

        let outline = try square.outlined(width: 3)

        #expect(outline.pixels[32 * 64 + 17] == 255)
        #expect(outline.pixels[32 * 64 + 32] < 50)
        #expect(outline.pixels[2 * 64 + 2] == 0)
    }

    // MARK: - Replacing Folders

    @Test func failedWriteLeavesTheDestinationAsItWas() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("Icon.icon")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("original".utf8).write(to: destination.appendingPathComponent("file"))

        struct WriteFailed: Error {}
        #expect(throws: WriteFailed.self) {
            try FolderReplacement.replace(destination) { _ in throw WriteFailed() }
        }

        let original = try String(contentsOf: destination.appendingPathComponent("file"), encoding: .utf8)
        let filesInFolder = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(original == "original")
        #expect(filesInFolder == ["Icon.icon"])
    }
}

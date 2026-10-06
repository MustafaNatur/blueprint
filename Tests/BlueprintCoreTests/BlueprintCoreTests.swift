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

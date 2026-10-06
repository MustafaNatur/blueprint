import BlueprintCore
import BlueprintTestSupport
import Foundation
import Testing
@testable import blueprint

/// Tests what drawing a blueprint does the same for every format: picking the format,
/// and replacing files safely.
@Suite final class BlueprintIconTests {

    // MARK: - Fixtures

    private let folder = Fixtures.temporaryFolder()

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    private func url(_ name: String) -> URL {
        folder.appendingPathComponent(name)
    }

    /// Writes an icon in the format the name's extension says.
    private func writeIcon(named name: String) throws -> URL {
        let icon = url(name)
        if name.hasSuffix(".icon") {
            try Fixtures.writeIcon(at: icon, image: Fixtures.layerPNG())
        } else {
            try Fixtures.writeIconSet(at: icon, slots: [Fixtures.iosSlot()], imageSide: 256)
        }
        return icon
    }

    private static let formats = ["icon", "appiconset"]

    // MARK: - Picking a Format

    @Test(arguments: formats) func drawsTheBlueprintInTheSourceFormat(_ fileExtension: String) throws {
        let source = try writeIcon(named: "App.\(fileExtension)")
        let destination = url("AppDebug.\(fileExtension)")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())

        #expect(BlueprintIcon.isBlueprint(destination))
    }

    @Test func refusesOtherFiles() throws {
        #expect(throws: BlueprintError.unsupportedFormat("Logo.png")) {
            try BlueprintIcon.generate(from: self.url("Logo.png"), to: self.url("LogoDebug.png"), style: BlueprintStyle())
        }
    }

    @Test func refusesADestinationInAnotherFormat() throws {
        let source = try writeIcon(named: "App.appiconset")

        #expect(throws: BlueprintError.formatMismatch("App.appiconset", "AppDebug.icon")) {
            try BlueprintIcon.generate(from: source, to: self.url("AppDebug.icon"), style: BlueprintStyle())
        }
    }

    @Test func otherFilesAreNotBlueprints() {
        #expect(!BlueprintIcon.isBlueprint(url("Logo.png")))
    }

    // MARK: - Replacing Safely

    @Test(arguments: formats) func replacesABlueprintItDrewBefore(_ fileExtension: String) throws {
        let source = try writeIcon(named: "App.\(fileExtension)")
        let destination = url("AppDebug.\(fileExtension)")

        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle())
        try BlueprintIcon.generate(from: source, to: destination, style: BlueprintStyle(showsGrid: false))

        #expect(BlueprintIcon.isBlueprint(destination))
    }

    @Test(arguments: formats) func refusesToOverwriteAnotherIcon(_ fileExtension: String) throws {
        let source = try writeIcon(named: "App.\(fileExtension)")
        let otherIcon = try writeIcon(named: "Other.\(fileExtension)")

        #expect(throws: BlueprintError.wouldOverwriteIcon("Other.\(fileExtension)")) {
            try BlueprintIcon.generate(from: source, to: otherIcon, style: BlueprintStyle())
        }
        #expect(!BlueprintIcon.isBlueprint(otherIcon))
    }

    @Test(arguments: formats) func refusesToRedrawABlueprint(_ fileExtension: String) throws {
        let source = try writeIcon(named: "App.\(fileExtension)")
        let blueprint = url("AppDebug.\(fileExtension)")
        try BlueprintIcon.generate(from: source, to: blueprint, style: BlueprintStyle())
        let blueprintOfBlueprint = url("AppDebugDebug.\(fileExtension)")

        #expect(throws: BlueprintError.alreadyBlueprint("AppDebug.\(fileExtension)")) {
            try BlueprintIcon.generate(from: blueprint, to: blueprintOfBlueprint, style: BlueprintStyle())
        }
    }

    @Test(arguments: formats) func leavesNoTemporaryFilesBehind(_ fileExtension: String) throws {
        let source = try writeIcon(named: "App.\(fileExtension)")

        try BlueprintIcon.generate(from: source, to: url("AppDebug.\(fileExtension)"), style: BlueprintStyle())

        let filesInFolder = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(filesInFolder.sorted() == ["App.\(fileExtension)", "AppDebug.\(fileExtension)"])
    }
}

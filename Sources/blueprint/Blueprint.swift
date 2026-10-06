import ArgumentParser
import BlueprintCore
import Foundation

/// The `blueprint` command: draws a blueprint of an app icon and opens it.
///
/// ```
/// $ blueprint MyApp/AppIcon.icon
/// ✓ Drew AppIconDebug.icon from 3 layers of AppIcon.icon
///
/// $ blueprint MyApp/Assets.xcassets/AppIcon.appiconset
/// ✓ Drew AppIconDebug.appiconset from 1 layer of AppIcon.appiconset
/// ```
@main
struct Blueprint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blueprint",
        abstract: "Draw a blueprint version of an app icon for your debug builds.",
        discussion: """
        Works with Icon Composer .icon files and asset catalog .appiconset folders, and saves \
        the blueprint in the same format.
        """,
        version: "1.2.0"
    )

    // MARK: - Arguments

    @Argument(help: "The .icon or .appiconset to redraw.")
    var icon: String

    @Option(name: [.short, .long], help: """
    Where to write the blueprint. (default: <Name>Debug.icon in the current folder, \
    or <Name>Debug.appiconset next to the original)
    """)
    var output: String?

    @Option(help: "Background colors from top to bottom, comma-separated. One color gives a flat background.")
    var color = BlueprintStyle.xcodeBackgroundColors.joined(separator: ",")

    @Option(help: "Outline width, in icon points (the icon is 1024 pt).")
    var lineWidth = 9.0

    @Flag(inversion: .prefixedNo, help: "Draw the grid behind the drawing.")
    var grid = true

    @Flag(inversion: .prefixedNo, help: "Open the result: .icon in Icon Composer, .appiconset in Finder.")
    var open = true

    // MARK: - Running

    func run() throws {
        let layerCount = try drawBlueprint()
        let layers = layerCount == 1 ? "1 layer" : "\(layerCount) layers"
        print("✓ Drew \(destination.lastPathComponent) from \(layers) of \(source.lastPathComponent)")
        if open {
            show(destination)
        }
    }

    private func drawBlueprint() throws -> Int {
        let style = try style()
        do {
            return try BlueprintIcon.generate(from: source, to: destination, style: style)
        } catch BlueprintError.wouldOverwriteIcon(let name) {
            throw ValidationError("\(name) already exists and isn't a blueprint icon. Pick another name with --output.")
        }
    }

    // MARK: - Inputs

    private var source: URL {
        URL(fileURLWithPath: icon)
    }

    private var isAppIconSet: Bool {
        source.pathExtension.lowercased() == "appiconset"
    }

    /// Next to the original for an `.appiconset`, since Xcode only finds icon sets inside
    /// their asset catalog; in the current folder for an `.icon`.
    private var destination: URL {
        if let output {
            return URL(fileURLWithPath: output)
        }
        let currentPath = FileManager.default.currentDirectoryPath
        let currentFolder = URL(fileURLWithPath: currentPath)
        let folder = isAppIconSet ? source.deletingLastPathComponent() : currentFolder

        let sourceName = source.deletingPathExtension().lastPathComponent
        let blueprintName = "\(sourceName)Debug.\(source.pathExtension)"
        return folder.appendingPathComponent(blueprintName)
    }

    private func style() throws -> BlueprintStyle {
        let backgroundColors = color.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return try BlueprintStyle(backgroundColors: backgroundColors, lineWidth: lineWidth, showsGrid: grid)
    }

    // MARK: - Showing the Result

    private func show(_ blueprint: URL) {
        let openArguments = isAppIconSet ? ["-R", blueprint.path] : ["-b", "com.apple.IconComposer", blueprint.path]
        let opening = Process()
        opening.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        opening.arguments = openArguments
        opening.standardError = FileHandle.nullDevice
        try? opening.run()
        opening.waitUntilExit()
        if opening.terminationStatus != 0, !isAppIconSet {
            let message = "  Couldn't open Icon Composer. It comes with Xcode 26 or later.\n"
            FileHandle.standardError.write(Data(message.utf8))
        }
    }
}

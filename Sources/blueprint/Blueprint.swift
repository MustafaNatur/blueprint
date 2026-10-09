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
///
/// $ blueprint MyApp/AppIcon.icon --badge UAT --output AppIconUAT.icon
/// ✓ Drew AppIconUAT.icon with a badge from 3 layers of AppIcon.icon
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
        version: "1.3.0"
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

    @Option(help: """
    Text of a badge in the bottom right corner, such as DEV, UAT or BETA. Long text wraps \
    onto more lines. Drawn in the last --color.
    """)
    var badge: String?

    @Flag(inversion: .prefixedNo, help: "Draw the grid behind the drawing.")
    var grid = true

    @Flag(inversion: .prefixedNo, help: "Open the result: .icon in Icon Composer, .appiconset in Finder.")
    var open = true

    // MARK: - Running

    func run() throws {
        let style = try style()
        let layerCount = try drawBlueprint(style: style)
        let layers = layerCount == 1 ? "1 layer" : "\(layerCount) layers"
        let badgeNote = style.badge == nil ? "" : " with a badge"
        print("✓ Drew \(destination.lastPathComponent)\(badgeNote) from \(layers) of \(source.lastPathComponent)")
        if open {
            show(destination)
        }
    }

    private func drawBlueprint(style: BlueprintStyle) throws -> Int {
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
        let blueprintBadge = try badge.map(BlueprintBadge.init(text:))
        return try BlueprintStyle(backgroundColors: backgroundColors, lineWidth: lineWidth, showsGrid: grid, badge: blueprintBadge)
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

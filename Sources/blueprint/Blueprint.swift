import ArgumentParser
import BlueprintKit
import Foundation

/// The `blueprint` command: draws a blueprint of an Icon Composer icon and opens it.
///
/// ```
/// $ blueprint MyApp/AppIcon.icon
/// ✓ Drew AppIconDebug.icon from 3 layers of AppIcon.icon
/// ```
@main
struct Blueprint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blueprint",
        abstract: "Draw a blueprint version of an Icon Composer icon and open it in Icon Composer.",
        version: "1.1.0"
    )

    @Argument(help: "The .icon file to redraw.")
    var icon: String

    @Option(name: [.short, .long], help: "Where to write the blueprint. (default: <Name>Debug.icon in the current folder)")
    var output: String?

    @Option(help: "Background colors from top to bottom, comma-separated. One color gives a flat background.")
    var color = BlueprintStyle.xcodePaper.joined(separator: ",")

    @Option(help: "Outline width, in icon points (the icon is 1024 pt).")
    var lineWidth = 9.0

    @Flag(help: "Leave out the grid behind the drawing.")
    var noGrid = false

    @Flag(help: "Don't open the result in Icon Composer.")
    var noOpen = false

    // MARK: - Running

    func run() throws {
        let style = try BlueprintStyle(
            paperHexes: color.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            lineWidth: lineWidth,
            showsGrid: !noGrid
        )
        let source = URL(fileURLWithPath: icon)
        let destination = output.map { URL(fileURLWithPath: $0) }
            ?? currentDirectory.appendingPathComponent(source.deletingPathExtension().lastPathComponent + "Debug.icon")

        let layers = try BlueprintIcon.generate(from: source, to: destination, style: style)
        print("✓ Drew \(destination.lastPathComponent) from \(layers) layer\(layers == 1 ? "" : "s") of \(source.lastPathComponent)")

        if !noOpen {
            try openInIconComposer(destination)
        }
    }

    // MARK: - Helpers

    private var currentDirectory: URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func openInIconComposer(_ icon: URL) throws {
        let open = Process()
        open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        open.arguments = ["-b", "com.apple.IconComposer", icon.path]
        open.standardError = FileHandle.nullDevice
        try open.run()
        open.waitUntilExit()
        if open.terminationStatus != 0 {
            print("  Couldn't open Icon Composer. It comes with Xcode 26 or later.")
        }
    }
}

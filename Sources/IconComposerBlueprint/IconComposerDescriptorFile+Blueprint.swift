import BlueprintCore
import Foundation
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Drawing a Blueprint

    /// Returns a blueprint of this icon, in memory.
    ///
    /// Every layer keeps its name, position and visibility, but its image is replaced
    /// by a white outline of its shape. Glass, shadows and translucency are turned off,
    /// and a "Blueprint Paper" group with the grid and the background is added behind
    /// everything else. In Icon Composer the result reads:
    ///
    /// ```
    /// Drawing            (or the original group's name)
    ///   Rectangle 1      Rectangle 1.svg
    ///   Rectangle 2      Rectangle 2.svg
    /// Blueprint Paper
    ///   Grid             Grid.svg
    ///   Background       Background.svg
    /// ```
    ///
    /// Use ``BlueprintIcon/generate(from:to:style:)`` to read, convert and save an
    /// icon in one step.
    ///
    /// - Parameter style: The background colors, line width and grid of the blueprint.
    /// - Returns: The blueprint, ready to be written to disk.
    /// - Throws: ``BlueprintError/missingLayerImage(_:)`` when a layer refers to an
    ///   image that isn't in the bundle, and any error from tracing a layer.
    package func blueprint(style: BlueprintStyle) throws -> IconComposerDescriptorFile {
        let outlineFileNames = outlineFileNames()
        let outlines = try outlineImages(named: outlineFileNames, lineWidth: style.lineWidth)

        let drawingGroups = drawingGroups(showing: outlineFileNames)
        let paperGroup = Self.paperGroup(style)
        let paperImages = Self.paperImages(style)

        let fillColor = try parseHexIconColor(style.middleBackgroundColor)

        var blueprint = document
        blueprint.fill = .solid(fillColor)
        blueprint.fillSpecializations = nil
        blueprint.groups = drawingGroups + [paperGroup]

        let assets = outlines.merging(paperImages) { _, paperImage in paperImage }
        return IconComposerDescriptorFile(document: blueprint, assets: assets)
    }

    // MARK: - Drawing

    /// Every layer of the icon, in every group.
    var allLayers: [IconLayer] {
        document.groups.flatMap(\.layers)
    }

    /// Returns the original groups drawn matte, with their layers showing outlines.
    private func drawingGroups(showing outlineFileNames: [String: String]) -> [IconGroup] {
        document.groups.enumerated().map { index, group in
            let fallbackName = index == 0 ? "Drawing" : "Drawing \(index + 1)"
            return group.outlined(using: outlineFileNames, fallbackName: fallbackName)
        }
    }

    /// Returns the traced outline of every image, keyed by the outline's file name.
    private func outlineImages(named outlineFileNames: [String: String], lineWidth: Double) throws -> [String: Data] {
        try outlineFileNames.reduce(into: [:]) { outlines, names in
            let (imageName, outlineFileName) = names
            guard let image = assets[imageName] else { throw BlueprintError.missingLayerImage(imageName) }
            let layerScale = largestScale(of: imageName)
            let tracer = LayerTracer(lineWidth: lineWidth, layerScale: layerScale)
            outlines[outlineFileName] = try tracer.trace(image, named: imageName)
        }
    }

    /// Returns the file name of each image's outline, keyed by the image's own name.
    ///
    /// An outline is named after the first layer that shows its image, so the files in
    /// `Assets` match the layer list; images used only in appearance variants keep
    /// their own names.
    private func outlineFileNames() -> [String: String] {
        let layerImages: [(imageName: String, title: String)] = allLayers.compactMap { layer in
            guard let imageName = layer.imageName else { return nil }
            let title = layer.name ?? imageName.withoutExtension
            return (imageName, title)
        }
        let allImages = referencedImageNames.sorted().map { imageName in
            (imageName: imageName, title: imageName.withoutExtension)
        }
        let titledImages = layerImages + allImages

        var fileNames = UniqueFileNames(reserving: [Self.gridFileName, Self.backgroundFileName])
        var outlineFileNames: [String: String] = [:]
        for (imageName, title) in titledImages where outlineFileNames[imageName] == nil {
            outlineFileNames[imageName] = fileNames.next(for: title)
        }
        return outlineFileNames
    }

    /// Returns the largest scale any layer draws an image at.
    private func largestScale(of imageName: String) -> Double {
        let layersShowingImage = allLayers.filter { $0.shows(imageName) }
        let scales = layersShowingImage.flatMap(\.allScales)
        return scales.max() ?? 1
    }

    // MARK: - Paper

    /// The name of the group that holds the grid and the background, which also marks an icon as a blueprint.
    static let paperGroupName = "Blueprint Paper"
    static let gridFileName = "Grid.svg"
    static let backgroundFileName = "Background.svg"

    private static func paperGroup(_ style: BlueprintStyle) -> IconGroup {
        let grid = IconLayer(name: "Grid", imageName: gridFileName, glass: false)
        let background = IconLayer(name: "Background", imageName: backgroundFileName, glass: false)
        let layers = style.showsGrid ? [grid, background] : [background]
        return .matte(name: paperGroupName, layers: layers)
    }

    private static func paperImages(_ style: BlueprintStyle) -> [String: Data] {
        let background = BlueprintPaper.background(colors: style.backgroundColors)
        var images = [backgroundFileName: background]
        if style.showsGrid {
            images[gridFileName] = BlueprintPaper.grid()
        }
        return images
    }
}

// MARK: - Unique File Names

/// Hands out `.svg` file names that are unique ignoring case, because they become
/// file names on a case-insensitive disk.
private struct UniqueFileNames {
    private var taken: Set<String>

    init(reserving names: [String]) {
        taken = Set(names.map { $0.lowercased() })
    }

    /// Returns `"<title>.svg"`, or `"<title> 2.svg"` and so on when that's taken.
    mutating func next(for title: String) -> String {
        let titleWithoutSlashes = title.replacingOccurrences(of: "/", with: "-")
        let base = titleWithoutSlashes.replacingOccurrences(of: ":", with: "-")
        var name = "\(base).svg"
        var number = 2
        while taken.contains(name.lowercased()) {
            name = "\(base) \(number).svg"
            number += 1
        }
        taken.insert(name.lowercased())
        return name
    }
}

// MARK: - Matte Groups and Outlined Layers

private extension IconGroup {
    /// Creates a group drawn matte: no shadow, translucency or specular highlights.
    static func matte(
        id: String? = nil,
        name: String?,
        layers: [IconLayer],
        hidden: Bool? = nil,
        hiddenSpecializations: [Specialization<Bool>]? = nil,
        positionSpecializations: [Specialization<IconPosition>]? = nil
    ) -> IconGroup {
        IconGroup(
            id: id,
            name: name,
            layers: layers,
            hidden: hidden,
            shadow: IconShadow(kind: .none, opacity: 0),
            translucency: .disabled,
            specular: false,
            hiddenSpecializations: hiddenSpecializations,
            positionSpecializations: positionSpecializations
        )
    }

    /// Returns this group drawn matte, with its layers showing their outlines.
    func outlined(using outlineFileNames: [String: String], fallbackName: String) -> IconGroup {
        let outlinedLayers = layers.map { $0.outlined(using: outlineFileNames) }
        return .matte(
            id: id,
            name: name ?? fallbackName,
            layers: outlinedLayers,
            hidden: hidden,
            hiddenSpecializations: hiddenSpecializations,
            positionSpecializations: positionSpecializations
        )
    }
}

private extension IconLayer {
    /// Returns this layer showing its image's outline, keeping only its name, visibility
    /// and position. Opacity, blend mode, fill and glass are left out.
    func outlined(using outlineFileNames: [String: String]) -> IconLayer {
        let outlineFileName = imageName.flatMap { outlineFileNames[$0] }
        let outlineVariants = imageNameSpecializations?.map { variant in
            let variantOutline = outlineFileNames[variant.value] ?? variant.value
            return Specialization(appearance: variant.appearance, idiom: variant.idiom, value: variantOutline)
        }
        return IconLayer(
            id: id,
            name: name ?? outlineFileName?.withoutExtension,
            imageName: outlineFileName,
            hidden: hidden,
            glass: false,
            position: position,
            imageNameSpecializations: outlineVariants,
            hiddenSpecializations: hiddenSpecializations,
            positionSpecializations: positionSpecializations
        )
    }

    /// Whether the layer shows the image in any appearance.
    func shows(_ imageName: String) -> Bool {
        let variantImageNames = (imageNameSpecializations ?? []).map(\.value)
        return self.imageName == imageName || variantImageNames.contains(imageName)
    }

    /// The layer's scale in every appearance.
    var allScales: [Double] {
        let scale = position?.scale ?? 1
        let variantScales = (positionSpecializations ?? []).map(\.value.scale)
        return [scale] + variantScales
    }
}

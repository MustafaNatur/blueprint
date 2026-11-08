import AppKit
import BlueprintCore
import IconKit

extension IconComposerDescriptorFile {

    // MARK: - Drawing a Blueprint

    /// Returns a blueprint of this icon, in memory.
    ///
    /// Every layer keeps its name, position and visibility, but its image is replaced
    /// by a white outline of its shape. Glass, shadows and translucency are turned off,
    /// and a "Blueprint Paper" group with the grid and the background is added behind
    /// everything else. A style with a badge adds a "Badge" group in front. In Icon
    /// Composer the result reads:
    ///
    /// ```
    /// Badge              (only with a badge)
    ///   Badge            Badge.svg
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
    /// - Parameter style: The background colors, line width, grid and badge of the blueprint.
    /// - Returns: The blueprint, ready to be written to disk.
    /// - Throws: ``BlueprintError/missingLayerImage(_:)`` when a layer refers to an
    ///   image that isn't in the bundle, and any error from tracing a layer.
    package func blueprint(style: BlueprintStyle) throws -> IconComposerDescriptorFile {
        let outlineFileNames = outlineFileNames()
        let outlines = try outlineImages(named: outlineFileNames, lineWidth: style.lineWidth)

        let drawingGroups = drawingGroups(showing: outlineFileNames)
        let paperGroup = Self.paperGroup(style)
        let paperImages = Self.paperImages(style)
        let badgeGroups = Self.badgeGroups(style)
        let badgeImages = try Self.badgeImages(style)

        let fillColor = try parseHexIconColor(style.middleBackgroundColor)

        var blueprint = document
        blueprint.fill = .solid(fillColor)
        blueprint.fillSpecializations = nil
        blueprint.groups = badgeGroups + drawingGroups + [paperGroup]

        let blueprintImages = paperImages.merging(badgeImages) { _, badgeImage in badgeImage }
        let assets = outlines.merging(blueprintImages) { _, blueprintImage in blueprintImage }
        return IconComposerDescriptorFile(document: blueprint, assets: assets)
    }

    // MARK: - Drawing

    /// Every layer of the icon, in every group.
    var allLayers: [IconLayer] {
        document.groups.flatMap(\.layers)
    }

    /// Returns the original groups drawn matte, with their layers showing outlines.
    private func drawingGroups(showing outlineFileNames: OutlineFileNames) -> [IconGroup] {
        document.groups.enumerated().map { index, group in
            let fallbackName = index == 0 ? "Drawing" : "Drawing \(index + 1)"
            let layerOutlines = group.layers.indices.map { outlineFileNames.layers[LayerIndex(group: index, layer: $0)] }
            return group.outlined(layerOutlines: layerOutlines, variantOutlines: outlineFileNames.variants, fallbackName: fallbackName)
        }
    }

    /// Returns the traced outline of every layer and of every image shown only in an
    /// appearance variant, keyed by the outline's file name.
    ///
    /// A layer's outline stops wherever a shown layer without glass in front of it is
    /// opaque, the way the original hides what's behind it. Variant images aren't cut.
    private func outlineImages(named outlineFileNames: OutlineFileNames, lineWidth: Double) throws -> [String: Data] {
        let placedLayers = try placedLayers()
        var outlines: [String: Data] = [:]
        for (index, placed) in placedLayers.enumerated() {
            guard let outlineFileName = outlineFileNames.layers[placed.index] else { continue }
            let inFront = placedLayers[..<index].filter(\.covers)
            let tracer = LayerTracer(lineWidth: lineWidth, layerScale: largestScale(of: placed.imageName))
            let cover: ((CGContext, CGSize) -> Void)? = inFront.isEmpty ? nil : { _, pixelSize in
                placed.draw(inFront, into: pixelSize)
            }
            outlines[outlineFileName] = try tracer.trace(placed.imageData, named: placed.imageName, cover: cover)
        }
        for (imageName, outlineFileName) in outlineFileNames.variants {
            guard let image = assets[imageName] else { throw BlueprintError.missingLayerImage(imageName) }
            let tracer = LayerTracer(lineWidth: lineWidth, layerScale: largestScale(of: imageName))
            outlines[outlineFileName] = try tracer.trace(image, named: imageName)
        }
        return outlines
    }

    /// Returns every layer that shows an image, front to back, placed on the canvas.
    private func placedLayers() throws -> [PlacedLayer] {
        var placedLayers: [PlacedLayer] = []
        for (groupIndex, group) in document.groups.enumerated() {
            for (layerIndex, layer) in group.layers.enumerated() {
                guard let imageName = layer.imageName else { continue }
                guard let imageData = assets[imageName] else { throw BlueprintError.missingLayerImage(imageName) }
                guard let image = NSImage(data: imageData) else { throw BlueprintError.unreadableLayerImage(imageName) }
                placedLayers.append(PlacedLayer(
                    index: LayerIndex(group: groupIndex, layer: layerIndex),
                    imageName: imageName,
                    imageData: imageData,
                    image: image,
                    frame: PlacedLayer.frame(of: image, at: layer.position ?? .identity),
                    opacity: (layer.opacity ?? 1) * (group.opacity ?? 1),
                    covers: layer.glass == false && layer.hidden != true && group.hidden != true
                ))
            }
        }
        return placedLayers
    }

    /// Returns the file name of each layer's outline and of each variant image's outline.
    ///
    /// A layer's outline is named after the layer, so the files in `Assets` match the
    /// layer list; images used only in appearance variants keep their own names.
    private func outlineFileNames() -> OutlineFileNames {
        var fileNames = UniqueFileNames(reserving: [Self.gridFileName, Self.backgroundFileName, Self.badgeFileName])
        var outlineFileNames = OutlineFileNames()
        for (groupIndex, group) in document.groups.enumerated() {
            for (layerIndex, layer) in group.layers.enumerated() {
                guard let imageName = layer.imageName else { continue }
                let title = layer.name ?? imageName.withoutExtension
                outlineFileNames.layers[LayerIndex(group: groupIndex, layer: layerIndex)] = fileNames.next(for: title)
            }
        }
        let variantImageNames = Set(allLayers.flatMap { ($0.imageNameSpecializations ?? []).map(\.value) })
        for imageName in variantImageNames.sorted() {
            outlineFileNames.variants[imageName] = fileNames.next(for: imageName.withoutExtension)
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
            images[gridFileName] = BlueprintPaper.grid(corners: style.showsGridCorners)
        }
        return images
    }
}

// MARK: - Badge

extension IconComposerDescriptorFile {
    static let badgeFileName = "Badge.svg"

    /// The group in front of the drawing that shows the badge, if the style has one.
    private static func badgeGroups(_ style: BlueprintStyle) -> [IconGroup] {
        guard style.badge != nil else { return [] }
        let badge = IconLayer(name: "Badge", imageName: badgeFileName, glass: false)
        return [.matte(name: "Badge", layers: [badge])]
    }

    private static func badgeImages(_ style: BlueprintStyle) throws -> [String: Data] {
        guard let badgePainter = BadgePainter(style: style) else { return [:] }
        return [badgeFileName: try badgePainter.svg()]
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
    func outlined(layerOutlines: [String?], variantOutlines: [String: String], fallbackName: String) -> IconGroup {
        let outlinedLayers = zip(layers, layerOutlines).map { $0.outlined(as: $1, variantOutlines: variantOutlines) }
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
    func outlined(as outlineFileName: String?, variantOutlines: [String: String]) -> IconLayer {
        let outlineVariants = imageNameSpecializations?.map { variant in
            let variantOutline = variantOutlines[variant.value] ?? variant.value
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

// MARK: - Layers in Front

/// Where a layer sits in the icon: its group and its place in the group.
private struct LayerIndex: Hashable {
    let group: Int
    let layer: Int
}

/// The outline file names of a blueprint: one per layer, and one per image shown only
/// in an appearance variant.
private struct OutlineFileNames {
    var layers: [LayerIndex: String] = [:]
    var variants: [String: String] = [:]
}

/// A layer that shows an image, with the image's frame on the canvas.
private struct PlacedLayer {
    let index: LayerIndex
    let imageName: String
    let imageData: Data
    let image: NSImage
    /// The image's frame on the canvas in points, top left origin.
    let frame: CGRect
    let opacity: Double
    /// Whether the layer hides what's behind it: it's shown and isn't glass, which
    /// Icon Composer draws see-through.
    let covers: Bool

    /// Icon Composer centers an image on the canvas, scales it and then moves it.
    static func frame(of image: NSImage, at position: IconPosition) -> CGRect {
        let size = LayerTracer.pointSize(of: image)
        let width = size.width * position.scale
        let height = size.height * position.scale
        let canvas = BlueprintPaper.canvasSize
        return CGRect(
            x: (canvas - width) / 2 + position.translationX,
            y: (canvas - height) / 2 + position.translationY,
            width: width,
            height: height
        )
    }

    /// Draws the layers into the current context, which holds this layer's image at
    /// the given pixel size.
    func draw(_ layers: [PlacedLayer], into pixelSize: CGSize) {
        let pixelsPerPoint = pixelSize.width / frame.width
        for layer in layers {
            let width = layer.frame.width * pixelsPerPoint
            let height = layer.frame.height * pixelsPerPoint
            let x = (layer.frame.minX - frame.minX) * pixelsPerPoint
            let top = (layer.frame.minY - frame.minY) * pixelsPerPoint
            let rect = CGRect(x: x, y: pixelSize.height - top - height, width: width, height: height)
            layer.image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: layer.opacity)
        }
    }
}

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
    /// - Parameter style: The paper colors, line width and grid of the blueprint.
    /// - Returns: The blueprint, ready to be written to disk.
    /// - Throws: ``BlueprintError/missingLayerImage(_:)`` when a layer refers to an
    ///   image that isn't in the bundle, and any error from tracing a layer.
    public func blueprint(style: BlueprintStyle) throws -> IconComposerDescriptorFile {
        if let missing = validateAssets().first {
            throw BlueprintError.missingLayerImage(missing)
        }

        let tracedNames = tracedAssetNames()
        var assets: [String: Data] = [:]
        for (imageName, tracedName) in tracedNames {
            let tracer = LayerTracer(lineWidth: style.lineWidth, layerScale: largestScale(of: imageName))
            assets[tracedName] = try tracer.trace(self.assets[imageName]!, named: imageName)
        }

        var document = self.document
        document.fill = .solid(style.baseFill)
        document.fillSpecializations = nil
        document.groups = document.groups.enumerated().map { index, group in
            group.flattened(renaming: tracedNames, fallbackName: index == 0 ? "Drawing" : "Drawing \(index + 1)")
        }

        var paperLayers: [IconLayer] = []
        if style.showsGrid {
            assets[Self.gridAssetName] = BlueprintPaper.grid()
            paperLayers.append(IconLayer(name: "Grid", imageName: Self.gridAssetName, glass: false))
        }
        assets[Self.backgroundAssetName] = BlueprintPaper.background(colors: style.paperHexes)
        paperLayers.append(IconLayer(name: "Background", imageName: Self.backgroundAssetName, glass: false))
        document.groups.append(.flat(name: Self.paperGroupName, layers: paperLayers))

        return IconComposerDescriptorFile(document: document, assets: assets)
    }

    // MARK: - Paper Names

    /// The name of the group that holds the paper, which also marks an icon as a blueprint.
    static let paperGroupName = "Blueprint Paper"

    /// The file name of the grid image.
    static let gridAssetName = "Grid.svg"

    /// The file name of the background image.
    static let backgroundAssetName = "Background.svg"

    // MARK: - Layer Images

    /// Returns the file name of each traced image, keyed by the original image name.
    ///
    /// A traced image is named after the first layer that shows it, so the files in
    /// `Assets` match the layer list; images used only in appearance variants keep
    /// their own names. Names are unique ignoring case, because they become file
    /// names on a case-insensitive disk, and never clash with the paper images.
    private func tracedAssetNames() -> [String: String] {
        var names: [String: String] = [:]
        var taken: Set<String> = [Self.gridAssetName.lowercased(), Self.backgroundAssetName.lowercased()]

        func claim(_ imageName: String, as title: String) {
            guard names[imageName] == nil else { return }
            let base = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            var candidate = "\(base).svg", number = 2
            while taken.contains(candidate.lowercased()) {
                candidate = "\(base) \(number).svg"
                number += 1
            }
            taken.insert(candidate.lowercased())
            names[imageName] = candidate
        }

        for layer in document.groups.flatMap(\.layers) {
            if let imageName = layer.imageName {
                claim(imageName, as: layer.name ?? (imageName as NSString).deletingPathExtension)
            }
        }
        for imageName in referencedImageNames.sorted() {
            claim(imageName, as: (imageName as NSString).deletingPathExtension)
        }
        return names
    }

    /// Returns the largest scale any layer draws an image at.
    ///
    /// Outlines are traced at the image's own size, so dividing the line width by
    /// this scale keeps them at the requested width in the finished icon.
    private func largestScale(of imageName: String) -> Double {
        let scales = document.groups.flatMap(\.layers)
            .filter { $0.imageName == imageName || $0.imageNameSpecializations?.contains { $0.value == imageName } == true }
            .flatMap { layer in [layer.position?.scale ?? 1] + (layer.positionSpecializations ?? []).map(\.value.scale) }
        return scales.max() ?? 1
    }
}

// MARK: - Flat Groups and Layers

private extension IconGroup {
    /// Creates a group drawn flat, without shadow, translucency or specular highlights.
    static func flat(name: String?, layers: [IconLayer]) -> IconGroup {
        IconGroup(
            name: name,
            layers: layers,
            shadow: IconShadow(kind: .none, opacity: 0),
            translucency: .disabled,
            specular: false
        )
    }

    /// Returns this group drawn flat, with its layers pointing at their traced images.
    func flattened(renaming tracedNames: [String: String], fallbackName: String) -> IconGroup {
        var group = IconGroup.flat(name: name ?? fallbackName, layers: layers.map { $0.flattened(renaming: tracedNames) })
        group.id = id
        group.hidden = hidden
        group.hiddenSpecializations = hiddenSpecializations
        group.positionSpecializations = positionSpecializations
        return group
    }
}

private extension IconLayer {
    /// Returns this layer without glass, showing its traced image in the same place.
    func flattened(renaming tracedNames: [String: String]) -> IconLayer {
        let tracedName = imageName.flatMap { tracedNames[$0] }
        return IconLayer(
            id: id,
            name: name ?? tracedName.map { ($0 as NSString).deletingPathExtension },
            imageName: tracedName,
            hidden: hidden,
            glass: false,
            position: position,
            imageNameSpecializations: imageNameSpecializations?.map {
                Specialization(appearance: $0.appearance, idiom: $0.idiom, value: tracedNames[$0.value] ?? $0.value)
            },
            hiddenSpecializations: hiddenSpecializations,
            positionSpecializations: positionSpecializations
        )
    }
}

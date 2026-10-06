import Foundation
import IconKit

extension IconComposerDescriptorFile {
    /// The same composition redrawn as a blueprint: every layer keeps its name and
    /// place, but turns into white line work on blue graph paper with no glass or shadows.
    ///
    /// In Icon Composer it reads as the original groups, renamed "Drawing" when
    /// unnamed, above a "Blueprint Paper" group holding the grid and the background.
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

    static let paperGroupName = "Blueprint Paper"
    static let gridAssetName = "Grid.svg"
    static let backgroundAssetName = "Background.svg"

    /// Each traced image is named after the first layer that shows it, so the
    /// files in Assets match the layer list. Images used only in appearance
    /// variants keep their own names.
    ///
    /// Names are compared ignoring case: they become file names, and on a
    /// case-insensitive disk a layer called `background` would overwrite the paper.
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

    /// Line width is set in final icon points, so it is divided by the scale the
    /// layer is drawn at; the largest scale keeps lines from getting too thick.
    private func largestScale(of imageName: String) -> Double {
        let scales = document.groups.flatMap(\.layers)
            .filter { $0.imageName == imageName || $0.imageNameSpecializations?.contains { $0.value == imageName } == true }
            .flatMap { layer in [layer.position?.scale ?? 1] + (layer.positionSpecializations ?? []).map(\.value.scale) }
        return scales.max() ?? 1
    }
}

private extension IconGroup {
    static func flat(name: String?, layers: [IconLayer]) -> IconGroup {
        IconGroup(
            name: name,
            layers: layers,
            shadow: IconShadow(kind: .none, opacity: 0),
            translucency: .disabled,
            specular: false
        )
    }

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

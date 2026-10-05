import Foundation
import IconKit

extension IconComposerDescriptorFile {
    /// The same composition redrawn as a blueprint: every layer keeps its place,
    /// but turns into white line work on blue graph paper with no glass or shadows.
    public func blueprint(style: BlueprintStyle) throws -> IconComposerDescriptorFile {
        if let missing = validateAssets().first {
            throw BlueprintError.missingLayerImage(missing)
        }

        var tracedNames: [String: String] = [:]
        var assets: [String: Data] = [:]
        for name in referencedImageNames.sorted() {
            let tracer = LayerTracer(lineWidth: style.lineWidth, layerScale: largestScale(of: name))
            let tracedName = Self.tracedAssetName(for: name)
            assets[tracedName] = try tracer.trace(self.assets[name]!, named: name)
            tracedNames[name] = tracedName
        }

        var document = self.document
        document.fill = .solid(style.baseFill)
        document.fillSpecializations = nil
        document.groups = document.groups.map { $0.flattened(renaming: tracedNames) }

        assets[Self.paperAssetName] = BlueprintPaper.svg(colors: style.paperHexes, showsGrid: style.showsGrid)
        document.groups.append(.flat(layers: [IconLayer(name: "Paper", imageName: Self.paperAssetName, glass: false)]))
        return IconComposerDescriptorFile(document: document, assets: assets)
    }

    static let paperAssetName = "Blueprint Paper.svg"

    /// Asset names are file names, so on a case-insensitive disk a layer image
    /// called `paper.svg` would overwrite the paper and lose its outline.
    static func tracedAssetName(for imageName: String) -> String {
        let base = "Blueprint " + (imageName as NSString).deletingPathExtension
        let name = base + ".svg"
        return name.caseInsensitiveCompare(paperAssetName) == .orderedSame ? base + " Layer.svg" : name
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
    static func flat(layers: [IconLayer]) -> IconGroup {
        IconGroup(
            layers: layers,
            shadow: IconShadow(kind: .none, opacity: 0),
            translucency: .disabled,
            specular: false
        )
    }

    func flattened(renaming tracedNames: [String: String]) -> IconGroup {
        var group = IconGroup.flat(layers: layers.map { $0.flattened(renaming: tracedNames) })
        group.id = id
        group.name = name
        group.hidden = hidden
        group.hiddenSpecializations = hiddenSpecializations
        group.positionSpecializations = positionSpecializations
        return group
    }
}

private extension IconLayer {
    func flattened(renaming tracedNames: [String: String]) -> IconLayer {
        IconLayer(
            id: id,
            name: name,
            imageName: imageName.flatMap { tracedNames[$0] },
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

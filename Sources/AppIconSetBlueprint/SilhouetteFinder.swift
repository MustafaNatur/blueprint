import BlueprintCore
import CoreImage
import Vision

/// Finds the foreground of a flat icon: white where the foreground is, black over the background.
protocol SilhouetteFinder {
    func silhouette(of icon: RGBAImage) throws -> AlphaMask
}

/// Uses Vision's subject lifting, the same as "Lift subject from background" in Photos.
///
/// Everything Vision sees in front of the background becomes one shape: separate or
/// overlapping objects merge into a single silhouette.
struct SubjectSilhouette: SilhouetteFinder {
    func silhouette(of icon: RGBAImage) throws -> AlphaMask {
        let image = try icon.cgImage()
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])

        guard let subjects = request.results?.first else {
            return AlphaMask(width: icon.width, height: icon.height) { _, _ in 0 }
        }
        let maskBuffer = try subjects.generateScaledMaskForImage(forInstances: subjects.allInstances, from: handler)
        let maskImage = CIImage(cvPixelBuffer: maskBuffer)
        return AlphaMask.rendering(maskImage, width: icon.width, height: icon.height)
    }
}

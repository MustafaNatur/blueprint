import AppKit
import BlueprintCore
import Testing
@testable import AppIconSetBlueprint

/// Tests finding the foreground of a flat icon by its colors.
@Suite struct ColorSilhouetteTests {

    // MARK: - Fixtures

    private let side = 256
    private let finder = ColorSilhouette()

    private let red = NSColor(srgbRed: 0.86, green: 0.1, blue: 0.15, alpha: 1)
    private let navy = NSColor(srgbRed: 0.05, green: 0.1, blue: 0.3, alpha: 1)

    /// Draws an icon, with the origin at the bottom left.
    private func icon(_ draw: () -> Void) throws -> RGBAImage {
        try RGBAImage(width: side, height: side) { _ in draw() }
    }

    /// The mask's value at a point, counted from the top left.
    private func value(of mask: AlphaMask, x: Int, y: Int) -> UInt8 {
        mask.pixels[y * mask.width + x]
    }

    // MARK: - Silhouettes

    /// Shapes that run off the edge of a red background, which Vision's subject lifting couldn't find.
    @Test func findsShapesThatRunOffTheEdge() throws {
        let icon = try icon {
            red.setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: 80, y: -80, width: 210, height: 210)).fill()
            navy.setFill()
            NSRect(x: 0, y: 150, width: 90, height: 40).fill()
        }

        let mask = try finder.silhouette(of: icon)

        let inTheCircle = value(of: mask, x: 200, y: 230)
        let inTheBar = value(of: mask, x: 2, y: 86)
        let inTheBackground = value(of: mask, x: 128, y: 20)
        #expect(inTheCircle == 255)
        #expect(inTheBar == 255)
        #expect(inTheBackground == 0)
    }

    @Test func keepsSmallShapesApartFromTheMainOne() throws {
        let icon = try icon {
            red.setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
            NSColor.white.setFill()
            NSRect(x: 60, y: 60, width: 100, height: 100).fill()
            NSRect(x: 200, y: 30, width: 12, height: 12).fill()
        }

        let mask = try finder.silhouette(of: icon)

        let inTheSmallSquare = value(of: mask, x: 206, y: 220)
        #expect(inTheSmallSquare == 255)
    }

    @Test func followsAGradientBackground() throws {
        let icon = try icon {
            let top = NSColor(srgbRed: 1, green: 0.7, blue: 0.3, alpha: 1)
            let bottom = NSColor(srgbRed: 0.45, green: 0.15, blue: 0.8, alpha: 1)
            let gradient = NSGradient(starting: top, ending: bottom)
            gradient?.draw(in: NSRect(x: 0, y: 0, width: side, height: side), angle: -45)
            NSColor.white.setFill()
            NSRect(x: 96, y: 96, width: 64, height: 64).fill()
        }

        let mask = try finder.silhouette(of: icon)

        let inTheSquare = value(of: mask, x: 128, y: 128)
        let inTheTopLeftCorner = value(of: mask, x: 4, y: 4)
        let inTheBottomRightCorner = value(of: mask, x: 251, y: 251)
        #expect(inTheSquare == 255)
        #expect(inTheTopLeftCorner == 0)
        #expect(inTheBottomRightCorner == 0)
    }

    /// A macOS icon: a rounded plate with a shadow, on a transparent margin.
    @Test func leavesOutTheMarginAndShadowOfAMacIcon() throws {
        let icon = try icon {
            let plate = NSBezierPath(roundedRect: NSRect(x: 25, y: 25, width: 206, height: 206), xRadius: 46, yRadius: 46)
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = NSSize(width: 0, height: -4)
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            red.setFill()
            plate.fill()
            NSGraphicsContext.restoreGraphicsState()
            NSColor.white.setFill()
            NSRect(x: 96, y: 96, width: 64, height: 64).fill()
        }

        let mask = try finder.silhouette(of: icon)

        let inTheSquare = value(of: mask, x: 128, y: 128)
        let onThePlate = value(of: mask, x: 60, y: 128)
        let inTheShadow = value(of: mask, x: 128, y: 236)
        let inTheMargin = value(of: mask, x: 5, y: 5)
        #expect(inTheSquare == 255)
        #expect(onThePlate == 0)
        #expect(inTheShadow == 0)
        #expect(inTheMargin == 0)
    }

    @Test func plainIconHasNoForeground() throws {
        let icon = try icon {
            red.setFill()
            NSRect(x: 0, y: 0, width: side, height: side).fill()
        }

        let mask = try finder.silhouette(of: icon)

        #expect(mask.isEmpty)
    }

    @Test func transparentIconHasNoForeground() throws {
        let icon = try icon {}

        let mask = try finder.silhouette(of: icon)

        #expect(mask.isEmpty)
    }

    // MARK: - Oklab

    @Test func whiteIsFullyLightAndHasNoHue() {
        let white = OKLabColor(red: 1, green: 1, blue: 1)

        #expect(abs(white.lightness - 1) < 0.001)
        #expect(abs(white.greenRed) < 0.001)
        #expect(abs(white.blueYellow) < 0.001)
    }

    @Test func blackAndWhiteAreOneApart() {
        let black = OKLabColor(red: 0, green: 0, blue: 0)
        let white = OKLabColor(red: 1, green: 1, blue: 1)

        let distance = black.distance(to: white)

        #expect(abs(distance - 1) < 0.001)
    }
}

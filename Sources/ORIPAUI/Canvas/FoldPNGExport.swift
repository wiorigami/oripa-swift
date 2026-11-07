// Port of `oripa-port/src/js/render/PngExport.js` — `ORIPA.render.renderFmPng` for the
// folded model (the browser canvas equivalent of the Android
// `io/export/OffscreenGLRenderer*` + `ExporterImage` PNG export path).
//
// The browser version creates an offscreen `<canvas>`; here the shared `FoldRenderer`
// draws into a Core Graphics bitmap context (same drawing code as the live fold screen)
// and the bitmap is encoded as PNG with ImageIO. Works on iOS and macOS.
//
// Fit mirrors `AbstractOffscreenGLRenderer.setViewport`: content is centred and scaled to
// 95% of the frame with `setViewport(-d, -d, d, d)` where `d = foldedModelHalfSize`; the
// cross view uses the landscape split (FM left / CP right), the CP panel scaled by
// `d / maxHalf`.
import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import ORIPACore

/// Folded-model PNG export (replaces the browser `<canvas>.toDataURL("image/png")`).
public enum FoldPNGExport {

    /// `renderFmPng(fm, mode, w, h, opts)` options.
    public struct Options {
        public var wireframe: Bool
        public var flip: Bool
        public var frontColor: UInt32
        public var backColor: UInt32
        public var lineColor: UInt32
        public var overlapShadow: Bool
        /// `paint_pref_fold_overlap`: when false the Overlap export is blank (Java parity).
        public var overlapEnabled: Bool
        public var cp: CreasePattern?
        public var crossLineManager: CrossLineManager?
        public var crossPosition: Int
        public var crossAngleDeg: Int
        /// `background` opt: default white; `nil` renders a transparent PNG.
        public var background: CGColor?

        public init(wireframe: Bool = false,
                    flip: Bool = false,
                    frontColor: UInt32 = FoldRenderDefaults.frontColor,
                    backColor: UInt32 = FoldRenderDefaults.backColor,
                    lineColor: UInt32 = FoldRenderDefaults.lineColor,
                    overlapShadow: Bool = false,
                    overlapEnabled: Bool = true,
                    cp: CreasePattern? = nil,
                    crossLineManager: CrossLineManager? = nil,
                    crossPosition: Int = 0,
                    crossAngleDeg: Int = 0,
                    background: CGColor? = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)) {
            self.wireframe = wireframe
            self.flip = flip
            self.frontColor = frontColor
            self.backColor = backColor
            self.lineColor = lineColor
            self.overlapShadow = overlapShadow
            self.overlapEnabled = overlapEnabled
            self.cp = cp
            self.crossLineManager = crossLineManager
            self.crossPosition = crossPosition
            self.crossAngleDeg = crossAngleDeg
            self.background = background
        }
    }

    /// `renderFmPng(...)`: PNG bytes for the folded model in `mode`.
    ///
    /// `width`/`height` are output pixels. The fold export dialog uses
    /// `size x size` for x-ray/overlap and `2*size x size` for the Cut Line view
    /// (Java `getFoldedModelCross(i*2, i)`); the renderer treats one pixel as one point
    /// (the offscreen renderer had no device-pixel-ratio scaling, like the web export).
    @MainActor
    public static func render(fm: FoldedModel?,
                              mode: FoldMode,
                              width: Int,
                              height: Int,
                              options: Options = Options()) -> Data? {
        guard let fm else { return nil }
        let pixelWidth = max(1, width)
        let pixelHeight = max(1, height)
        let w = CGFloat(pixelWidth)
        let h = CGFloat(pixelHeight)
        let d = CGFloat(fm.foldedModelHalfSize)

        let renderer = FoldRenderer()
        renderer.background = options.background

        // Same configuration order as renderFmPng.
        renderer.setFoldedModel(fm)
        if mode == .cross {
            renderer.setMode(.cross)
            renderer.setCreasePattern(options.cp)
            renderer.setPreferences(FoldRenderPreferences(wireframe: options.wireframe,
                                                          flip: options.flip))
            var crossOptions = FoldRenderOptions()
            crossOptions.crossAngleDeg = options.crossAngleDeg
            crossOptions.crossPosition = options.crossPosition
            renderer.setOptions(crossOptions)
            renderer.setCrossLineManager(options.crossLineManager)
        } else {
            renderer.setMode(mode == .overlap ? .overlap : .xray)
            renderer.setPreferences(FoldRenderPreferences(wireframe: options.wireframe,
                                                          overlapEnabled: options.overlapEnabled,
                                                          overlapShadow: options.overlapShadow,
                                                          flip: options.flip,
                                                          frontColor: options.frontColor,
                                                          backColor: options.backColor,
                                                          lineColor: options.lineColor))
        }
        renderer.resize(w, h)

        // Fit like AbstractOffscreenGLRenderer.setViewport: centred, 95%, one content
        // half-size per axis. The fit uses the full-frame panel height; the split-view
        // panel rect assignment happens afterwards in setCameras (as in the JS).
        let unitScale = (min(w, h) / (2.0 * d)) * 0.95
        func fit(_ camera: Camera, centerX: CGFloat, centerY: CGFloat, dataScale: CGFloat) {
            let k = camera.pixelsPerWorldUnit()
            camera.scale = unitScale / k * dataScale
            camera.tx = -camera.scale * centerX
            camera.ty = -camera.scale * centerY
            camera.rotationDeg = 0
        }

        if mode == .cross {
            // Java `ExporterImage.getFoldedModelCross`: the CP data is transformed by
            // `translate(-centre)` then `scale(d / cpMaxHalf)` into folded-model object space,
            // and both panels render the standard ±d viewport (95% fit). The web port's
            // `cpFit = 1 / maxHalf` is a browser-only path bug; the Java semantics are ported
            // here so the exported Cut Line image matches the on-screen split view.
            var cpMaxHalf: CGFloat = d
            var centerX: CGFloat = 0
            var centerY: CGFloat = 0
            if let cp = options.cp {
                let maxHalfSize = cp.minMaxCheck.getMaxHalfSize()
                if maxHalfSize > 0 {
                    cpMaxHalf = CGFloat(maxHalfSize)
                    centerX = CGFloat(cp.minMaxCheck.getCenterX())
                    centerY = CGFloat(cp.minMaxCheck.getCenterY())
                } else if cp.creasePatternHalfSize > 0 {
                    cpMaxHalf = CGFloat(cp.creasePatternHalfSize)
                }
            }
            let panel = renderer.panelRect(.top)
            let panelK = panel.height / (2.0 * d)
            let fitHalf = 0.95 * min(panel.width, panel.height) / 2.0
            let top = Camera()
            top.setViewport(w, h)
            top.setObjectHalfSize(d)
            let bottom = Camera()
            bottom.setViewport(w, h)
            bottom.setObjectHalfSize(d)
            bottom.scale = fitHalf / (panelK * d)
            bottom.tx = 0
            bottom.ty = 0
            bottom.rotationDeg = 0
            top.scale = fitHalf / (panelK * cpMaxHalf)
            top.tx = -top.scale * centerX
            top.ty = -top.scale * centerY
            top.rotationDeg = 0
            renderer.setCameras(FoldCameraPair(top: top, bottom: bottom))
        } else {
            let camera = Camera()
            camera.setViewport(w, h)
            camera.setObjectHalfSize(d)
            fit(camera, centerX: 0, centerY: 0, dataScale: 1.0)
            renderer.setCamera(camera)
        }

        guard let context = CGContext(data: nil,
                                      width: pixelWidth,
                                      height: pixelHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        renderer.draw(in: context, size: CGSize(width: w, height: h))
        guard let image = context.makeImage() else { return nil }
        return encodePNG(image)
    }

    /// Encode a CGImage as PNG data (cross-platform ImageIO; no UIKit/AppKit).
    public static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData,
                                                                UTType.png.identifier as CFString,
                                                                1,
                                                                nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

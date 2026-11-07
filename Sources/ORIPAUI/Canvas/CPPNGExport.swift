// Port of `oripa-port/src/js/render/PngExport.js` — `renderCpPng` / thumbnail part.
//
// Offscreen replacement for Android `io/export/OffscreenGLRendererCp` + ExporterImage
// (PNG data URLs). Uses SwiftUI `ImageRenderer` on a `Canvas`-based view (works headless
// on macOS and iOS, no window server needed) and encodes the resulting CGImage as PNG
// with ImageIO.
//
// Fit matches AbstractOffscreenGLRenderer.setViewport: content is centred and scaled to
// 95% of the frame, one content-half-size per axis. Lengths scale with the output size
// (relative appearance of the on-screen view at 512 px). `options.thumbnail` = every
// line, no grid, no vertices — used for the 180 px project thumbnails.
//
// `render(cp:width:height:options:)` (the contract §5.3 facade taking a CreasePattern)
// lives in `Screens/Editor/CoreRenderBridge.swift` because this canvas file has no
// ORIPACore dependency.
import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Everything the CP PNG exporter needs from a crease pattern, in object space.
public struct CPPngData {
    public var halfSize: CGFloat
    public var gridLines: [PaintLine]
    public var lines: [PaintLine]
    public var minMax: CanvasMinMax

    public init(halfSize: CGFloat, gridLines: [PaintLine] = [], lines: [PaintLine],
                minMax: CanvasMinMax? = nil) {
        self.halfSize = halfSize
        self.gridLines = gridLines
        self.lines = lines
        self.minMax = minMax ?? CanvasMinMax(halfSize: halfSize)
    }
}

public struct CPPNGExportOptions {
    /// nil = transparent background.
    public var background: CanvasRGB? = CanvasRGB(1.0, 1.0, 1.0)
    public var showGrid: Bool = false
    public var showFlatLines: Bool = true
    public var dashed: Bool = false
    /// Thumbnail mode: every line, no grid, no vertices (PngExport.js `opts.thumbnail`).
    public var thumbnail: Bool = false
    /// Android `ExporterImage.getCreasePatternArgb8888(..., lineWidthScale)`; the CP
    /// export dialog uses 2.0, thumbnails use 1.0.
    public var lineWidthScale: CGFloat = 1.0

    public init(background: CanvasRGB? = CanvasRGB(1.0, 1.0, 1.0),
                showGrid: Bool = false,
                showFlatLines: Bool = true,
                dashed: Bool = false,
                thumbnail: Bool = false,
                lineWidthScale: CGFloat = 1.0) {
        self.background = background
        self.showGrid = showGrid
        self.showFlatLines = showFlatLines
        self.dashed = dashed
        self.thumbnail = thumbnail
        self.lineWidthScale = lineWidthScale
    }
}

public enum CPPNGExport {
    /// Default size of the square project thumbnails (Constant.SINGLE_GRID_IMAGE_DIMEN_DP).
    public static let thumbnailSize = 180

    /// `renderCpPng(cp, width, height, opts)` → PNG bytes (nil on failure / empty cp).
    @MainActor
    public static func render(cpData: CPPngData, width: Int, height: Int,
                              options: CPPNGExportOptions = CPPNGExportOptions()) -> Data? {
        let w = max(1, width)
        let h = max(1, height)
        let view = CPPngCanvasView(data: cpData, options: options, width: CGFloat(w), height: CGFloat(h))
            .frame(width: CGFloat(w), height: CGFloat(h))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.isOpaque = options.background != nil
        guard let cgImage = renderer.cgImage else { return nil }
        return encodePNG(cgImage)
    }

    /// Project thumbnail: 180×180 px, every line, no grid (Java
    /// `ExporterImage.getCreasePatternThumb`).
    @MainActor
    public static func renderThumbnail(cpData: CPPngData, size: Int = thumbnailSize) -> Data? {
        render(cpData: cpData, width: size, height: size,
               options: CPPNGExportOptions(background: CanvasRGB(1.0, 1.0, 1.0),
                                           showGrid: false,
                                           showFlatLines: true,
                                           dashed: false,
                                           thumbnail: true,
                                           lineWidthScale: 1.0))
    }

    /// PNG bytes from a CGImage using ImageIO (cross-platform, no UIKit/AppKit).
    public static func encodePNG(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

// MARK: - Offscreen drawing view

/// Canvas drawing used by the PNG exporter (port of `renderCpPng`'s fit math).
public struct CPPngCanvasView: View {
    public let data: CPPngData
    public let options: CPPNGExportOptions
    public let width: CGFloat
    public let height: CGFloat

    public init(data: CPPngData, options: CPPNGExportOptions, width: CGFloat, height: CGFloat) {
        self.data = data
        self.options = options
        self.width = width
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .frame(width: width, height: height)
    }

    private struct Fit {
        var centerX: CGFloat
        var centerY: CGFloat
        var kx: CGFloat
        var ky: CGFloat

        func tx(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPoint {
            CGPoint(x: w / 2.0 + kx * (x - centerX), y: h / 2.0 + ky * (y - centerY))
        }
    }

    private func fit(size: CGSize) -> Fit {
        let minMax = data.minMax.isEmpty ? CanvasMinMax(halfSize: data.halfSize) : data.minMax
        let centerX = minMax.getCenterX()
        let centerY = minMax.getCenterY()
        let fMax = max(minMax.getMaxHalfSize(), 1e-6)
        return Fit(centerX: centerX, centerY: centerY,
                   kx: 0.95 * size.width / (2.0 * fMax),
                   ky: 0.95 * size.height / (2.0 * fMax))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        if let background = options.background {
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(CanvasColor.swiftUIColor(background)))
        }
        let fit = fit(size: size)
        let scaleRef = min(size.width, size.height) / 512.0
        let lineWidth = max(1.0, 2.0 * RenderStyle.cpLineHalfWidth * scaleRef) * options.lineWidthScale
        let gridWidth = max(1.0, 2.0 * RenderStyle.gridHalfWidth * scaleRef)

        // Grid (Java OffscreenGLRendererCp draws it before the lines).
        if options.showGrid, !data.gridLines.isEmpty {
            var path = Path()
            for line in data.gridLines {
                path.move(to: fit.tx(line.x0, line.y0, size.width, size.height))
                path.addLine(to: fit.tx(line.x1, line.y1, size.width, size.height))
            }
            context.stroke(path, with: .color(CanvasColor.swiftUIColor(CanvasColor.grid)),
                           style: StrokeStyle(lineWidth: gridWidth, lineCap: .butt))
        }

        // Lines: thumbnail = every line, export = M/V/B + flat when shown.
        var currentType = Int.min
        var currentColor = Color.black
        var currentStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
        for line in data.lines {
            let type = line.typeCode
            if !options.thumbnail {
                if !options.showFlatLines && type == 0 { continue }
                if type == 4 || type == 5 || type == 6 { continue }
            }
            guard let rgb = CanvasColor.lineType(type) else { continue }
            if type != currentType {
                currentType = type
                currentColor = CanvasColor.swiftUIColor(rgb)
                currentStyle = StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                if options.dashed && !options.thumbnail {
                    let dash = PaintRenderer.cpDashPattern(type: type, fullWidth: lineWidth)
                    if let pattern = dash.pattern {
                        currentStyle.dash = pattern
                        currentStyle.dashPhase = dash.offset
                    }
                }
            }
            let a = fit.tx(line.x0, line.y0, size.width, size.height)
            let b = fit.tx(line.x1, line.y1, size.width, size.height)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(path, with: .color(currentColor), style: currentStyle)
        }
    }
}

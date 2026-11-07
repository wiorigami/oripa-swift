// Port of `oripa-port/src/js/render/CheckRenderer.js`
// (com.origamitoolbox.oripa.editor.glview.GLRendererCheckCp).
//
// Draw order: pink face polygons (Color.COLOR_CP_POLYGON_FILL), typed CP lines,
// vertices, red error vertices (local flat-foldability failures).
//
// The Android view applies an extra fit transform after the default 0.5 gesture scale:
//   translate(-centre * 0.5) then scale(cpHalf / minMaxCheck.maxHalf).
//
// Data comes from the editor bridge (`CoreRenderBridge.swift`); this file has no
// ORIPACore dependency so the headless exporters can use it.
import CoreGraphics
import Foundation
import SwiftUI

/// One check face polygon in object space (`OriPolygon.points`).
public struct CheckPolygon: Equatable {
    public var points: [PaintPoint]

    public init(points: [PaintPoint]) {
        self.points = points
    }
}

public final class CheckRenderer: ObservableObject {
    public var viewTransform: ViewTransform

    @Published public private(set) var revision: Int = 0

    public private(set) var polygons: [CheckPolygon] = []
    public private(set) var lineSets: [[PaintLine]] = []
    public private(set) var points: [PaintPoint] = []
    public private(set) var errorPoints: [PaintPoint] = []

    public init(viewTransform: ViewTransform = ViewTransform()) {
        self.viewTransform = viewTransform
    }

    public func setViewTransform(_ vt: ViewTransform) {
        viewTransform = vt
    }

    public func requestDraw() {
        revision &+= 1
    }

    /// Replacement for `CheckRenderer.setCreasePattern(cp)`: applies the
    /// GLSurfaceViewCheckCp constructor transform and rebuilds the render data.
    public func setCreasePatternData(cpHalfSize: CGFloat,
                                     centerX: CGFloat,
                                     centerY: CGFloat,
                                     maxHalfSize: CGFloat,
                                     polygons: [CheckPolygon],
                                     lines: [PaintLine],
                                     points: [PaintPoint],
                                     errorPoints: [PaintPoint]) {
        let vt = viewTransform
        vt.setObjectHalfSize(cpHalfSize)
        vt.setScaleFactor(0.5)
        vt.identityTransformM()
        vt.scaleTransformWorldM(factor: 0.5, wx: 0.0, wy: 0.0)   // initializeRenderer()
        var scale: CGFloat = 1.0
        if maxHalfSize > 0 { scale = cpHalfSize / maxHalfSize }
        // GLSurfaceViewCheckCp: translate(-centre * mScaleFactor), then scale(fit).
        vt.translateTransformWorldM(dx: -centerX * 0.5, dy: -centerY * 0.5)
        vt.scaleTransformWorldM(factor: scale, wx: 0.0, wy: 0.0)

        self.polygons = polygons
        self.lineSets = PaintRenderer.splitLines(lines, showMvb: true, showFlat: true)
        self.points = points
        self.errorPoints = errorPoints
        requestDraw()
    }

    // MARK: - Drawing

    public func prepareForSize(_ size: CGSize) {
        if viewTransform.viewportW != size.width || viewTransform.viewportH != size.height {
            viewTransform.setViewport(size.width, size.height)
        }
    }

    /// Fan-triangulate + shrink 50% toward the centroid (GLDataCpPolygons.getRenderData),
    /// then batch every triangle into one path and fill once.
    private func buildPolygonPath(vt: ViewTransform) -> Path {
        var path = Path()
        for polygon in polygons where polygon.points.count >= 3 {
            let n = polygon.points.count
            var cx: CGFloat = 0
            var cy: CGFloat = 0
            for p in polygon.points {
                cx += p.x
                cy += p.y
            }
            cx /= CGFloat(n)
            cy /= CGFloat(n)
            var shrunk: [PaintPoint] = []
            shrunk.reserveCapacity(n)
            for p in polygon.points {
                shrunk.append(PaintPoint(x: (p.x - cx) * 0.5 + cx, y: (p.y - cy) * 0.5 + cy))
            }
            for j in 2..<n {
                let a = vt.objectToScreen(x: shrunk[0].x, y: shrunk[0].y)
                let b = vt.objectToScreen(x: shrunk[j - 1].x, y: shrunk[j - 1].y)
                let c = vt.objectToScreen(x: shrunk[j].x, y: shrunk[j].y)
                path.move(to: a)
                path.addLine(to: b)
                path.addLine(to: c)
                path.closeSubpath()
            }
        }
        return path
    }

    public func draw(in context: inout GraphicsContext, size: CGSize) {
        prepareForSize(size)
        let vt = viewTransform
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

        // Pink flat-foldable face polygons.
        if !polygons.isEmpty {
            let path = buildPolygonPath(vt: vt)
            context.fill(path, with: .color(CanvasColor.swiftUIColor(CanvasColor.cpPolygonFill)))
        }

        // Typed crease-pattern lines (mountain/valley/flat/boundary colours).
        if !lineSets.isEmpty {
            let width = RenderStyle.checkLineWidth
            for set in lineSets where !set.isEmpty {
                var currentType = Int.min
                var currentColor = Color.black
                for line in set {
                    if line.typeCode != currentType {
                        currentType = line.typeCode
                        let rgb = CanvasColor.lineType(line.typeCode) ?? CanvasColor.boundary
                        currentColor = CanvasColor.swiftUIColor(rgb)
                    }
                    let p0 = vt.objectToScreen(x: line.x0, y: line.y0)
                    let p1 = vt.objectToScreen(x: line.x1, y: line.y1)
                    var path = Path()
                    path.move(to: p0)
                    path.addLine(to: p1)
                    context.stroke(path, with: .color(currentColor),
                                   style: StrokeStyle(lineWidth: width, lineCap: .butt))
                }
            }
        }

        fillPoints(&context, points: points, vt: vt, size: RenderStyle.pointSizeDefault,
                   color: CanvasColor.swiftUIColor(CanvasColor.boundary))
        fillPoints(&context, points: errorPoints, vt: vt, size: RenderStyle.pointSizeEmphasis,
                   color: CanvasColor.swiftUIColor(CanvasColor.error))
    }

    private func fillPoints(_ context: inout GraphicsContext, points: [PaintPoint],
                            vt: ViewTransform, size: CGFloat, color: Color) {
        guard !points.isEmpty else { return }
        let half = size / 2.0
        var path = Path()
        for p in points {
            let s = vt.objectToScreen(x: p.x, y: p.y)
            path.addRect(CGRect(x: s.x - half, y: s.y - half, width: size, height: size))
        }
        context.fill(path, with: .color(color))
    }
}

// MARK: - SwiftUI view

public struct CheckCanvasView: View {
    @ObservedObject public var renderer: CheckRenderer
    private var redrawKey: Int { renderer.revision }

    public init(renderer: CheckRenderer) {
        self.renderer = renderer
    }

    public var body: some View {
        let _ = redrawKey
        Canvas { context, size in
            renderer.draw(in: &context, size: size)
        }
    }
}

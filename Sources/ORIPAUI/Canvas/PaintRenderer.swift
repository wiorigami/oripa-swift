// Port of `oripa-port/src/js/render/PaintRenderer.js` (Canvas-2D rebuild of
// com.origamitoolbox.oripa.editor.glview.GLRendererPaintCp) plus the shared
// `RenderUtil.js` palette/width constants.
//
// Draw order (same as GLRendererPaintCp.draw):
//   grid → crease-pattern lines → picked lines → mirror line → vertices →
//   picked vertices → picked point → touch circle → selection rectangle.
//
// Line widths are screen-constant in CSS px, exactly like the Android quad geometry
// (the GL code compensated the gesture scale factor every frame).
//
// The renderer is data-driven: the editor bridge (`CoreRenderBridge.swift`) converts
// `CreasePattern` render data into the plain value types in this file. That keeps the
// drawing layer free of ORIPACore imports (and usable by the headless PNG export).
import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Palette / style (port of RenderUtil.js)

public struct CanvasRGB: Equatable {
    public var r: CGFloat
    public var g: CGFloat
    public var b: CGFloat

    public init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
    }
}

/// Colour values from `ORIPA.Color` (Color.js) as CanvasRGB floats.
public enum CanvasColor {
    public static let boundary = CanvasRGB(0.0, 0.0, 0.0)
    public static let valley = CanvasRGB(0.0, 0.0, 1.0)
    public static let mountain = CanvasRGB(1.0, 0.0, 0.0)
    public static let flat = CanvasRGB(0.0, 1.0, 1.0)
    public static let grid = CanvasRGB(0.5, 0.5, 0.5)
    public static let slice = CanvasRGB(1.0, 0.0, 1.0)
    public static let picked = CanvasRGB(0.0, 1.0, 0.0)
    public static let error = CanvasRGB(1.0, 0.0, 0.0)
    public static let cpPolygonFill = CanvasRGB(1.0, 0.824, 0.824)
    public static let touchCircle = CanvasRGB(0.913, 0.117, 0.388)
    public static let selectionRect = CanvasRGB(0.913, 0.117, 0.388)

    /// LineType.getColor(byte): FLAT 0, BOUNDARY 1, MOUNTAIN 2, VALLEY 3,
    /// GRID 4, PICKED 5, SLICE 6, UNDEFINED 127 → nil.
    public static func lineType(_ typeCode: Int) -> CanvasRGB? {
        switch typeCode {
        case 0: return flat
        case 1: return boundary
        case 2: return mountain
        case 3: return valley
        case 4: return grid
        case 5: return picked
        case 6: return slice
        default: return nil
        }
    }

    public static func swiftUIColor(_ rgb: CanvasRGB, alpha: CGFloat = 1.0) -> Color {
        Color(.sRGB, red: Double(rgb.r), green: Double(rgb.g), blue: Double(rgb.b),
              opacity: Double(alpha))
    }

    public static func swiftUIColor(_ rgb: CanvasRGB, opacity: CGFloat) -> Color {
        swiftUIColor(rgb, alpha: opacity)
    }
}

/// Widths / point sizes / alphas from `RenderUtil.style` (CSS px; Android GL px are
/// converted with the reference density 3, the xxhdpi class of the APK).
public enum RenderStyle {
    public static let referenceDensity: CGFloat = 3.0

    public static func glPx(_ n: CGFloat) -> CGFloat { n / referenceDensity }

    /// Crease-pattern painting lines: quad half width LINE_HALF_WIDTH_DEFAULT_DP (1 dp).
    public static let cpLineHalfWidth: CGFloat = 1.0
    /// Grid half width LINE_HALF_WIDTH_GRID_DP (0.5 dp).
    public static let gridHalfWidth: CGFloat = 0.5
    /// Mirror line half width LINE_HALF_WIDTH_MIRROR_DP (3 dp).
    public static let mirrorLineHalfWidth: CGFloat = 3.0
    /// GLLineCpMVFB / GLLineOneColor draw GL_LINES with glLineWidth(LINE_WIDTH_DEFAULT 3).
    public static let checkLineWidth: CGFloat = glPx(3.0)
    public static let previewLineWidth: CGFloat = glPx(3.0)
    /// GLRectangleDashed: default line width 3 GL px.
    public static let selectionLineWidth: CGFloat = glPx(3.0)
    public static let selectionDashLengthScreen: CGFloat = 10.0
    public static let touchCircleAlpha: CGFloat = 0.38
    /// GLLineCpMVFB gl_PointSize POINT_SIZE_DEFAULT (12 GL px).
    public static let pointSizeDefault: CGFloat = glPx(12.0)
    /// POINT_SIZE_EMPHASIS (24 GL px).
    public static let pointSizeEmphasis: CGFloat = glPx(24.0)
}

/// `PaintRenderer.setPreferences` payload (camelCase names from the JS port).
public struct PaintRenderPreferences: Equatable {
    public var showGrid: Bool = true
    public var gridDivisions: Int = 4
    public var gridType: Int = 0
    public var showMvbLines: Bool = true
    public var showFlatLines: Bool = true
    public var showVertices: Bool = true
    public var useDashedLines: Bool = false

    public init() {}

    public init(showGrid: Bool, gridDivisions: Int, gridType: Int, showMvbLines: Bool,
                showFlatLines: Bool, showVertices: Bool, useDashedLines: Bool) {
        self.showGrid = showGrid
        self.gridDivisions = gridDivisions
        self.gridType = gridType
        self.showMvbLines = showMvbLines
        self.showFlatLines = showFlatLines
        self.showVertices = showVertices
        self.useDashedLines = useDashedLines
    }
}

// MARK: - Render data value types

/// One line in object (crease-pattern) space.
public struct PaintLine: Equatable {
    public var x0: CGFloat
    public var y0: CGFloat
    public var x1: CGFloat
    public var y1: CGFloat
    /// `LineType` raw value (0 flat, 1 boundary, 2 mountain, 3 valley, 4 grid, …).
    public var typeCode: Int

    public init(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat, typeCode: Int) {
        self.x0 = x0
        self.y0 = y0
        self.x1 = x1
        self.y1 = y1
        self.typeCode = typeCode
    }
}

/// One vertex in object space.
public struct PaintPoint: Equatable {
    public var x: CGFloat
    public var y: CGFloat

    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

// MARK: - PaintRenderer

public final class PaintRenderer: ObservableObject {
    // View transform (gesture math / viewport projection).
    public var viewTransform: ViewTransform

    public var preferences = PaintRenderPreferences()

    // SwiftUI redraw trigger (replaces the rAF-batched draw()).
    @Published public private(set) var revision: Int = 0

    // Render data.
    public private(set) var gridLines: [PaintLine] = []
    public private(set) var lineSets: [[PaintLine]] = []
    public private(set) var cpPoints: [PaintPoint] = []
    public private(set) var pickedMVFBPoints: [PaintPoint] = []
    public private(set) var pickedPoints: [PaintPoint] = []
    public private(set) var pickedLines: [PaintLine] = []
    public private(set) var mirrorLine: PaintLine?
    public private(set) var selectionRect: (x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat)?
    public private(set) var touchCircle: (x: CGFloat, y: CGFloat, radius: CGFloat)?

    public var useDashedLines = false
    public var lineWidthScaleFactor: CGFloat = 1.0
    public var currentScaleFactor: CGFloat = 0.5
    public var inputLineType: Int = 2

    public init(viewTransform: ViewTransform = ViewTransform()) {
        self.viewTransform = viewTransform
    }

    // MARK: Lifecycle / setup (JS names)

    public func setViewport(_ w: CGFloat, _ h: CGFloat) {
        viewTransform.setViewport(w, h)
    }

    public func setViewTransform(_ vt: ViewTransform) {
        viewTransform = vt
    }

    public func setObjectHalfSize(_ half: CGFloat) {
        viewTransform.setObjectHalfSize(half)
    }

    /// Rebuilds the filtered line/point render data from the crease pattern.
    ///
    /// `CoreRenderBridge` installs this closure so the renderer consumes the exact
    /// `GLDataCpLinesTypedWidth` / `GLDataCpSimple` encodings of the core model (this is
    /// what the JS `setCpLines` / `setCpPoints` call sites do). Keeping it as a closure
    /// means the drawing layer itself stays free of ORIPACore imports.
    public var renderDataProvider: ((PaintRenderPreferences) -> (lineSets: [[PaintLine]], points: [PaintPoint]))?

    /// Replacement for `PaintRenderer.setCreasePattern(cp)`; the bridge feeds it the
    /// converted grid + already filtered render data.
    public func setCreasePatternData(halfSize: CGFloat, gridLines: [PaintLine],
                                     lines: [PaintLine], points: [PaintPoint]) {
        viewTransform.setObjectHalfSize(halfSize)
        self.gridLines = gridLines
        let prefs = preferences
        setCpLineSets(PaintRenderer.splitLines(lines, showMvb: prefs.showMvbLines,
                                               showFlat: prefs.showFlatLines))
        setCpPointsData(PaintRenderer.filterPoints(points, showMvb: prefs.showMvbLines,
                                                   showFlat: prefs.showFlatLines))
    }

    /// Sets already-filtered, already-split typed line render data.
    public func setCpLineSets(_ sets: [[PaintLine]]) {
        lineSets = sets
    }

    /// Sets already-filtered vertex render data.
    public func setCpPointsData(_ points: [PaintPoint]) {
        cpPoints = points
    }

    public func setPreferences(_ prefs: PaintRenderPreferences) {
        preferences = prefs
        useDashedLines = prefs.useDashedLines
        refreshRenderData()
        requestDraw()
    }

    /// Re-runs the renderer's data provider (after CP edits or a preference change).
    public func refreshRenderData() {
        guard let provider = renderDataProvider else { return }
        let data = provider(preferences)
        setCpLineSets(data.lineSets)
        setCpPointsData(data.points)
    }

    public func setGridData(_ grid: [PaintLine]) {
        gridLines = grid
    }

    public func updateGrid(divisions: Int, gridType: Int, grid: [PaintLine]) {
        preferences.gridDivisions = divisions
        preferences.gridType = gridType
        setGridData(grid)
    }

    /// `GLDataCpLinesTypedWidth.getRenderDataSplit(cp.lineMVFB, showMvb, showFlat)`.
    public func setCpLines(_ lines: [PaintLine], prefs: PaintRenderPreferences) {
        lineSets = PaintRenderer.splitLines(lines, showMvb: prefs.showMvbLines,
                                            showFlat: prefs.showFlatLines)
    }

    /// `GLDataCpSimple.pointsToFloats(cp.pointMVFB, showMvb, showFlat)`.
    public func setCpPoints(_ points: [PaintPoint], prefs: PaintRenderPreferences) {
        cpPoints = PaintRenderer.filterPoints(points, showMvb: prefs.showMvbLines,
                                              showFlat: prefs.showFlatLines)
    }

    public func setPickedPoints(_ points: [PaintPoint]) {
        pickedPoints = points
        requestDraw()
    }

    public func setPickedMVFBPoints(_ points: [PaintPoint]) {
        pickedMVFBPoints = points
        requestDraw()
    }

    public func setPickedLines(_ lines: [PaintLine]) {
        pickedLines = lines
        requestDraw()
    }

    public func setMirrorLine(_ line: PaintLine?) {
        mirrorLine = line
        requestDraw()
    }

    public func setSelectionRect(x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat) {
        selectionRect = (x0: x0, y0: y0, x1: x1, y1: y1)
        requestDraw()
    }

    public func clearSelection() {
        selectionRect = nil
        requestDraw()
    }

    public func showTouchCircle(x: CGFloat, y: CGFloat, radius: CGFloat) {
        touchCircle = (x: x, y: y, radius: radius)
        requestDraw()
    }

    public func hideTouchCircle() {
        touchCircle = nil
        requestDraw()
    }

    public func setUseDashedLine(_ useDashed: Bool) {
        useDashedLines = useDashed
        requestDraw()
    }

    public func setLineWidthScaleFactor(_ f: CGFloat) {
        lineWidthScaleFactor = f
    }

    public func setCurrentScaleFactor(_ f: CGFloat) {
        currentScaleFactor = f
    }

    public func setInputLineType(_ typeCode: Int) {
        inputLineType = typeCode
        requestDraw()
    }

    public func requestDraw() {
        revision &+= 1
    }

    // MARK: - Filtering (port of GLDataCpLinesTypedWidth.getRenderDataSplit / GLDataCpSimple)

    /// Keeps MVFB (mountain/valley/boundary) and/or FLAT lines, exactly like
    /// `getRenderDataSplit(iterable, showMvb, showFlat)`.
    public static func splitLines(_ lines: [PaintLine], showMvb: Bool, showFlat: Bool) -> [[PaintLine]] {
        var filtered: [PaintLine] = []
        filtered.reserveCapacity(lines.count)
        for line in lines {
            let t = line.typeCode
            if (showMvb && showFlat)
                || (showMvb && (t == 2 || t == 3 || t == 1))
                || (showFlat && t == 0) {
                filtered.append(line)
            }
        }
        if filtered.isEmpty { return [] }
        // GLUtil.MAX_LINES_PER_SET = 10922; at most 6 sets.
        let maxPerSet = 10922
        let size = filtered.count
        let sets = min((size / maxPerSet) + (size % maxPerSet != 0 ? 1 : 0), 6)
        guard sets > 1 else { return [filtered] }
        var result: [[PaintLine]] = []
        for i in 0..<sets {
            let from = size * i / sets
            let to = size * (i + 1) / sets
            result.append(Array(filtered[from..<to]))
        }
        return result
    }

    /// Port of `GLDataCpSimple.pointsToFloats(iterable, showMvb, showFlat)`.
    public static func filterPoints(_ points: [PaintPoint], showMvb: Bool, showFlat: Bool) -> [PaintPoint] {
        guard showMvb || showFlat else { return [] }
        // The JS filters by the point's line-type counts (OriPoint.lineTypeCount):
        // kept if showMvb || has flat lines, and if showFlat || has M/V/B lines.
        // PaintPoint carries no counts; the bridge pre-filters using the JS rule and
        // this function only applies the "nothing shown" case. The bridge supplies
        // already-filtered points for parity.
        return points
    }

    // MARK: - Drawing

    public func prepareForSize(_ size: CGSize) {
        if viewTransform.viewportW != size.width || viewTransform.viewportH != size.height {
            viewTransform.setViewport(size.width, size.height)
        }
    }

    public func draw(in context: inout GraphicsContext, size: CGSize) {
        prepareForSize(size)
        let vt = viewTransform
        // White background (RenderUtil.WHITE).
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

        if preferences.showGrid {
            drawGrid(&context, vt: vt)
        }
        drawCpLines(&context, vt: vt)
        drawRawLines(&context, lines: pickedLines, vt: vt,
                     width: RenderStyle.cpLineHalfWidth * 2.0,
                     color: CanvasColor.swiftUIColor(CanvasColor.picked))
        if let mirrorLine {
            drawRawLines(&context, lines: [mirrorLine], vt: vt,
                         width: RenderStyle.mirrorLineHalfWidth * 2.0,
                         color: CanvasColor.swiftUIColor(CanvasColor.picked))
        }
        if preferences.showVertices {
            fillPoints(&context, points: cpPoints, vt: vt, size: RenderStyle.pointSizeDefault,
                       color: CanvasColor.swiftUIColor(CanvasColor.boundary))
        }
        if !pickedMVFBPoints.isEmpty {
            let rgb = CanvasColor.lineType(inputLineType) ?? CanvasColor.boundary
            fillPoints(&context, points: pickedMVFBPoints, vt: vt,
                       size: RenderStyle.pointSizeEmphasis,
                       color: CanvasColor.swiftUIColor(rgb))
        }
        if !pickedPoints.isEmpty {
            fillPoints(&context, points: pickedPoints, vt: vt,
                       size: RenderStyle.pointSizeEmphasis,
                       color: CanvasColor.swiftUIColor(CanvasColor.picked))
        }
        if let circle = touchCircle {
            let c = vt.objectToScreen(x: circle.x, y: circle.y)
            let r = vt.objectLengthToScreen(circle.radius)
            if r > 0 {
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect),
                             with: .color(CanvasColor.swiftUIColor(CanvasColor.touchCircle,
                                                                   opacity: RenderStyle.touchCircleAlpha)))
            }
        }
        if let rect = selectionRect {
            let pts = [
                vt.objectToScreen(x: rect.x0, y: rect.y0),
                vt.objectToScreen(x: rect.x1, y: rect.y0),
                vt.objectToScreen(x: rect.x1, y: rect.y1),
                vt.objectToScreen(x: rect.x0, y: rect.y1),
            ]
            var path = Path()
            path.move(to: pts[0])
            path.addLine(to: pts[1])
            path.addLine(to: pts[2])
            path.addLine(to: pts[3])
            path.closeSubpath()
            let dash = RenderStyle.selectionDashLengthScreen
            context.stroke(path,
                           with: .color(CanvasColor.swiftUIColor(CanvasColor.selectionRect)),
                           style: StrokeStyle(lineWidth: RenderStyle.selectionLineWidth,
                                              lineCap: .butt,
                                              dash: [dash, dash]))
        }
    }

    private func drawGrid(_ context: inout GraphicsContext, vt: ViewTransform) {
        guard !gridLines.isEmpty else { return }
        let width = RenderStyle.gridHalfWidth * 2.0
        var path = Path()
        for line in gridLines {
            let a = vt.objectToScreen(x: line.x0, y: line.y0)
            let b = vt.objectToScreen(x: line.x1, y: line.y1)
            path.move(to: a)
            path.addLine(to: b)
        }
        context.stroke(path, with: .color(CanvasColor.swiftUIColor(CanvasColor.grid)),
                       style: StrokeStyle(lineWidth: width, lineCap: .butt))
    }

    private func drawCpLines(_ context: inout GraphicsContext, vt: ViewTransform) {
        guard !lineSets.isEmpty else { return }
        let fullWidth = RenderStyle.cpLineHalfWidth * 2.0
        let dashed = useDashedLines
        for set in lineSets where !set.isEmpty {
            var currentType = Int.min
            var currentColor = Color.black
            var currentStyle = StrokeStyle(lineWidth: fullWidth, lineCap: .butt)
            for line in set {
                if line.typeCode != currentType {
                    currentType = line.typeCode
                    let rgb = CanvasColor.lineType(line.typeCode) ?? CanvasColor.boundary
                    currentColor = CanvasColor.swiftUIColor(rgb)
                    currentStyle = StrokeStyle(lineWidth: fullWidth, lineCap: .butt)
                    if dashed {
                        let d = PaintRenderer.cpDashPattern(type: line.typeCode, fullWidth: fullWidth)
                        if let pattern = d.pattern {
                            currentStyle.dash = pattern
                            currentStyle.dashPhase = d.offset
                        }
                    }
                }
                let a = vt.objectToScreen(x: line.x0, y: line.y0)
                let b = vt.objectToScreen(x: line.x1, y: line.y1)
                var path = Path()
                path.move(to: a)
                path.addLine(to: b)
                context.stroke(path, with: .color(currentColor), style: currentStyle)
            }
        }
    }

    private func drawRawLines(_ context: inout GraphicsContext, lines: [PaintLine],
                              vt: ViewTransform, width: CGFloat, color: Color) {
        guard !lines.isEmpty else { return }
        for line in lines {
            let a = vt.objectToScreen(x: line.x0, y: line.y0)
            let b = vt.objectToScreen(x: line.x1, y: line.y1)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: width, lineCap: .butt))
        }
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

    /// CP dashed-line patterns from GLLineCpMVFBDashed's fragment shader.
    /// `f = 2 * lineHalfWidth` in the shader = one full line width on screen.
    public static func cpDashPattern(type: Int, fullWidth f: CGFloat) -> (pattern: [CGFloat]?, offset: CGFloat) {
        switch type {
        case 2: // mountain
            return ([2 * f, 1 * f, 2 * f, 1 * f, 2 * f, 6 * f], 8 * f)
        case 3: // valley
            return ([3 * f, 2 * f], 0)
        case 0: // flat
            return ([1 * f, 1 * f], 0)
        default:
            return (nil, 0)
        }
    }
}

// MARK: - SwiftUI view

/// A `Canvas` that renders a `PaintRenderer`. Place it under a `CanvasGestureOverlay`.
public struct PaintCanvasView: View {
    @ObservedObject public var renderer: PaintRenderer
    /// Read to make SwiftUI re-evaluate the canvas when the renderer changes.
    private var redrawKey: Int { renderer.revision }

    public init(renderer: PaintRenderer) {
        self.renderer = renderer
    }

    public var body: some View {
        let _ = redrawKey
        Canvas { context, size in
            renderer.draw(in: &context, size: size)
        }
    }
}

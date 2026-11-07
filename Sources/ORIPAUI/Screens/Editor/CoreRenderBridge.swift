// Bridge between the ORIPACore crease-pattern model and the renderers in `ORIPAUI/Canvas`.
//
// The canvas layer is deliberately data-driven (plain `PaintLine` / `PaintPoint` values,
// no ORIPACore import) so it can be exercised headlessly and reused by the PNG exporters.
// This file is the single place that reads `CreasePattern` render data, mirroring the JS
// call sites:
//
//   PaintRenderer.setCreasePattern(cp)   -> grid.getRenderData(),
//                                           GLDataCpLinesTypedWidth.getRenderDataSplit(cp.lineMVFB, …),
//                                           GLDataCpSimple.pointsToFloats(cp.pointMVFB, …)
//   CheckRenderer.setCreasePattern(cp)   -> GLDataCpPolygons.getRenderData(cp.facesCheck),
//                                           GLDataCpLinesTyped.getRenderData(cp.lineMVFB, true, true),
//                                           GLDataCpSimple.pointsToFloats(cp.pointMVFB / pointErrorCheck)
//   PreviewRenderer.setCreasePattern(cp) -> cp.lineMVFB floats + pointMVFB.getMinMax(halfSize)
//   renderCpPng(cp, …)                   -> all lines + grid render data
import Foundation
import ORIPACore

@MainActor
public enum CoreRenderBridge {
    // MARK: - Line / point conversions

    public static func paintLine(_ line: OriLine) -> PaintLine {
        PaintLine(x0: CGFloat(line.start.x), y0: CGFloat(line.start.y),
                  x1: CGFloat(line.end.x), y1: CGFloat(line.end.y),
                  typeCode: line.typeValue)
    }

    public static func paintLines(_ lines: [OriLine]) -> [PaintLine] {
        lines.map(paintLine)
    }

    public static func paintPoints(_ points: [OriPoint]) -> [PaintPoint] {
        points.map { PaintPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
    }

    /// `[x0,y0,x1,y1,…]` (GLDataCpSimple encoding) -> points.
    public static func paintPoints(fromFloats floats: [Float]) -> [PaintPoint] {
        var out: [PaintPoint] = []
        out.reserveCapacity(floats.count / 2)
        var i = 0
        while i + 1 < floats.count {
            out.append(PaintPoint(x: CGFloat(floats[i]), y: CGFloat(floats[i + 1])))
            i += 2
        }
        return out
    }

    /// `GLDataCpLinesTypedWidth` quad data -> one segment per line
    /// (the JS `eachLineQuad` uses `drawOrder[i]` and `drawOrder[i] + 2`).
    public static func paintLines(fromTypedWidthSets sets: [GLDataCpLinesTypedWidth]) -> [[PaintLine]] {
        sets.map { data in
            let pos = data.vertexPosition
            let order = data.drawOrder
            let types = data.vertexType
            var lines: [PaintLine] = []
            lines.reserveCapacity(order.count / 6)
            var i = 0
            while i + 2 < order.count {
                let v0 = order[i]
                let v2 = v0 + 2
                if v0 >= 0, v2 * 2 + 1 < pos.count, pos.count > v0 * 2 + 1 {
                    lines.append(PaintLine(x0: CGFloat(pos[v0 * 2]),
                                           y0: CGFloat(pos[v0 * 2 + 1]),
                                           x1: CGFloat(pos[v2 * 2]),
                                           y1: CGFloat(pos[v2 * 2 + 1]),
                                           typeCode: v0 < types.count ? Int(types[v0]) : LineType.undefined.rawValue))
                }
                i += 6
            }
            return lines
        }
    }

    // MARK: - Grid

    /// `GridManager.getRenderData()` -> grid segments.
    ///
    /// `GridRenderData.vertexPosition` keeps the Java/JS quad encoding: each grid line
    /// contributes four vertices (start, start, end, end) so the GL shader can offset the
    /// quad by `±LINE_HALF_WIDTH_GRID_DP`, exactly like `GLDataLinesWidth` / the JS
    /// `eachLineQuad` (`drawOrder[i]` -> `drawOrder[i] + 2`). Canvas draws the same
    /// segment as a stroked line: vertex 0 -> vertex 2 = 8 floats per line.
    public static func gridLines(from data: GridRenderData) -> [PaintLine] {
        let pos = data.vertexPosition
        var out: [PaintLine] = []
        out.reserveCapacity(pos.count / 8)
        var i = 0
        while i + 7 < pos.count {
            out.append(PaintLine(x0: CGFloat(pos[i]), y0: CGFloat(pos[i + 1]),
                                 x1: CGFloat(pos[i + 4]), y1: CGFloat(pos[i + 5]),
                                 typeCode: LineType.grid.rawValue))
            i += 8
        }
        return out
    }

    /// `PaintRenderer.applyGrid()`: `cp.grid.update(divisions, gridType)` + render data.
    @discardableResult
    public static func updateGrid(_ cp: CreasePattern, divisions: Int, gridType: Int) -> [PaintLine] {
        do {
            try cp.grid.update(divisions, gridType)
        } catch {
            // Preference values are validated by the settings screen (2…256, grid type 0/1);
            // the JS renderer silently keeps the previous grid on the same Java exception.
        }
        return gridLines(from: cp.grid.getRenderData())
    }

    // MARK: - MinMax (pointMVFB.getMinMax)

    /// `RedBlackPointTree.getMinMax(halfSize)`: bounding box of the vertices, or the
    /// square `[-half, -half, half, half]` when the pattern has no vertices.
    public static func minMax(of points: [OriPoint], halfSize: CGFloat) -> CanvasMinMax {
        guard !points.isEmpty else { return CanvasMinMax(halfSize: halfSize) }
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CanvasMinMax(minX: CGFloat(minX), minY: CGFloat(minY),
                            maxX: CGFloat(maxX), maxY: CGFloat(maxY))
    }

    // MARK: - Paint renderer setup / refresh

    /// Installs the render-data provider so `setPreferences` / `refreshRenderData` reread the
    /// exact core render encodings (this is the port of `setCpLines` / `setCpPoints`).
    public static func installPaintProvider(_ renderer: PaintRenderer, cp: CreasePattern) {
        renderer.renderDataProvider = { prefs in
            let sets = GLDataCpLinesTypedWidth.getRenderDataSplit(cp.lines,
                                                                  prefs.showMvbLines,
                                                                  prefs.showFlatLines)
            let pointFloats = GLDataCpSimple.pointsToFloats(cp.points,
                                                            prefs.showMvbLines,
                                                            prefs.showFlatLines)
            return (lineSets: paintLines(fromTypedWidthSets: sets),
                    points: paintPoints(fromFloats: pointFloats))
        }
        renderer.refreshRenderData()
    }

    /// `PaintRenderer.setCreasePattern(cp)` + the grid + the parsed settings.
    public static func configurePaint(_ renderer: PaintRenderer,
                                      cp: CreasePattern,
                                      settings: EditorSettings) {
        renderer.setObjectHalfSize(CGFloat(cp.creasePatternHalfSize))
        renderer.setGridData(updateGrid(cp, divisions: settings.gridDivisions,
                                        gridType: settings.gridType))
        installPaintProvider(renderer, cp: cp)
        renderer.setInputLineType(cp.inputLineType.rawValue)
        renderer.setPreferences(settings.paintPreferences)
        renderer.requestDraw()
    }

    /// `refreshLinesPoints()`: rebuild the filtered render data after a CP edit.
    public static func refreshPaint(_ renderer: PaintRenderer, cp: CreasePattern) {
        renderer.refreshRenderData()
        renderer.requestDraw()
    }

    // MARK: - Check renderer setup

    /// `CheckRenderer.setCreasePattern(cp)` (cp.isFlatFoldable() must have run first).
    public static func configureCheck(_ renderer: CheckRenderer,
                                      cp: CreasePattern,
                                      settings: EditorSettings) {
        let half = CGFloat(cp.creasePatternHalfSize)
        let box = minMax(of: cp.points, halfSize: half)
        let polygons = cp.facesCheck.map { CheckPolygon(points: paintPoints($0.points)) }
        renderer.setCreasePatternData(cpHalfSize: half,
                                      centerX: box.getCenterX(),
                                      centerY: box.getCenterY(),
                                      maxHalfSize: max(box.getMaxHalfSize(), 0),
                                      polygons: polygons,
                                      lines: paintLines(cp.lines),
                                      points: paintPoints(cp.points),
                                      errorPoints: paintPoints(cp.pointErrorCheck))
        _ = settings
    }

    // MARK: - Preview renderer setup

    /// `PreviewRenderer.setCreasePattern(cp)`.
    public static func configurePreview(_ renderer: PreviewRenderer, cp: CreasePattern) {
        let half = CGFloat(cp.creasePatternHalfSize)
        renderer.setCreasePatternData(lines: paintLines(cp.lines),
                                      minMax: minMax(of: cp.points, halfSize: half))
    }

    // MARK: - PNG export (contract §5.3 facade)

    /// The data the PNG exporter needs, using the crease pattern's *current* grid data
    /// (the paint renderer keeps `cp.grid` updated; the export dialog uses the same grid
    /// preference like `PngExport.renderCpPng({showGrid})`).
    public static func cpPngData(_ cp: CreasePattern) -> CPPngData {
        CPPngData(halfSize: CGFloat(cp.creasePatternHalfSize),
                  gridLines: gridLines(from: cp.grid.getRenderData()),
                  lines: paintLines(cp.lines),
                  minMax: minMax(of: cp.points, halfSize: CGFloat(cp.creasePatternHalfSize)))
    }

    /// `CPPNGExport.render(cp:width:height:options:)` (contract §5.3).
    public static func renderPNG(cp: CreasePattern,
                                 width: Int,
                                 height: Int,
                                 options: CPPNGExportOptions = CPPNGExportOptions()) -> Data? {
        CPPNGExport.render(cpData: cpPngData(cp), width: width, height: height, options: options)
    }

    /// `io.getCreasePatternThumb(180, 180, cp)`: 180 px square project thumbnail.
    public static func renderThumbnail(cp: CreasePattern, size: Int = CPPNGExport.thumbnailSize) -> Data? {
        CPPNGExport.renderThumbnail(cpData: cpPngData(cp), size: size)
    }
}

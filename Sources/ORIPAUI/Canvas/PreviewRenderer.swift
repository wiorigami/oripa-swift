// Port of `oripa-port/src/js/render/PreviewRenderer.js`
// (com.origamitoolbox.oripa.editor.glview.GLRendererPreviewCP).
//
// Read-only crease pattern fitted to the view with a 5% margin; lines keep their
// line-type colour (same palette as the editor).
import CoreGraphics
import Foundation
import SwiftUI

/// Port of `com.origamitoolbox.oripa.util.MinMaxDouble` (only the parts the renderers
/// and PNG exporters need).
public struct CanvasMinMax: Equatable {
    public var minX: CGFloat
    public var minY: CGFloat
    public var maxX: CGFloat
    public var maxY: CGFloat

    public init(minX: CGFloat, minY: CGFloat, maxX: CGFloat, maxY: CGFloat) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(halfSize: CGFloat) {
        self.init(minX: -halfSize, minY: -halfSize, maxX: halfSize, maxY: halfSize)
    }

    public static let empty = CanvasMinMax(minX: .greatestFiniteMagnitude, minY: .greatestFiniteMagnitude,
                                           maxX: -.greatestFiniteMagnitude, maxY: -.greatestFiniteMagnitude)

    public var isEmpty: Bool { minX > maxX || minY > maxY }

    public func getCenterX() -> CGFloat { (minX + maxX) / 2.0 }
    public func getCenterY() -> CGFloat { (minY + maxY) / 2.0 }
    public func getHalfSizeX() -> CGFloat { maxX - getCenterX() }
    public func getHalfSizeY() -> CGFloat { maxY - getCenterY() }
    public func getMaxHalfSize() -> CGFloat { max(getHalfSizeX(), getHalfSizeY()) }
}

public final class PreviewRenderer: ObservableObject {
    public var viewTransform: ViewTransform

    @Published public private(set) var revision: Int = 0

    public private(set) var lines: [PaintLine] = []
    public private(set) var minMax: CanvasMinMax?

    /// scale / centerX / centerY / halfY (PreviewRenderer._updateFit).
    public private(set) var fit: (scale: CGFloat, centerX: CGFloat, centerY: CGFloat, halfY: CGFloat) =
        (scale: 0.95, centerX: 0, centerY: 0, halfY: 1)

    public init(viewTransform: ViewTransform = ViewTransform()) {
        self.viewTransform = viewTransform
    }

    public func requestDraw() {
        revision &+= 1
    }

    public func setCreasePatternData(lines: [PaintLine], minMax: CanvasMinMax) {
        self.lines = lines
        self.minMax = minMax
        updateFit()
        requestDraw()
    }

    private func updateFit() {
        guard let minMax else { return }
        let halfX = minMax.getHalfSizeX()
        let halfY = max(minMax.getHalfSizeY(), 1.0)
        let viewAspect = viewTransform.viewportH > 0
            ? viewTransform.viewportW / viewTransform.viewportH : 1.0
        let dataAspect = halfY != 0 ? halfX / halfY : 1.0
        let scale = (dataAspect > viewAspect) ? 0.95 * (viewAspect / dataAspect) : 0.95
        fit = (scale: scale, centerX: minMax.getCenterX(), centerY: minMax.getCenterY(),
               halfY: halfY)
    }

    public func prepareForSize(_ size: CGSize) {
        let changed = viewTransform.viewportW != size.width || viewTransform.viewportH != size.height
        viewTransform.setViewport(size.width, size.height)
        if changed { updateFit() }
    }

    public func draw(in context: inout GraphicsContext, size: CGSize) {
        prepareForSize(size)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        guard !lines.isEmpty else { return }

        let k = size.height > 0 ? size.height / (2.0 * fit.halfY) : 1.0
        let cx = size.width / 2.0
        let cy = size.height / 2.0
        func transform(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: cx + k * fit.scale * (x - fit.centerX),
                    y: cy + k * fit.scale * (y - fit.centerY))
        }

        var currentType = Int.min
        var currentColor = Color.black
        let style = StrokeStyle(lineWidth: RenderStyle.previewLineWidth, lineCap: .butt)
        for line in lines {
            if line.typeCode != currentType {
                currentType = line.typeCode
                let rgb = CanvasColor.lineType(line.typeCode) ?? CanvasColor.boundary
                currentColor = CanvasColor.swiftUIColor(rgb)
            }
            let a = transform(line.x0, line.y0)
            let b = transform(line.x1, line.y1)
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            context.stroke(path, with: .color(currentColor), style: style)
        }
    }
}

// MARK: - SwiftUI view

public struct PreviewCanvasView: View {
    @ObservedObject public var renderer: PreviewRenderer
    private var redrawKey: Int { renderer.revision }

    public init(renderer: PreviewRenderer) {
        self.renderer = renderer
    }

    public var body: some View {
        let _ = redrawKey
        Canvas { context, size in
            renderer.draw(in: &context, size: size)
        }
    }
}

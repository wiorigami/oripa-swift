// Port of `com.origamitoolbox.oripa.model.foldedmodel.CrossLineManager`
// (oripa-port src/js/core/model/foldedmodel/CrossLineManager.js).
//
// Keeps the current cut-line angle/position and its render data; `GLDataFmCrossLine` is built by
// the render-data layer (`RenderData/GLDataFmCrossLine.swift`, owned by fold-io).
import Foundation

public final class CrossLineManager {
    public var currentCrossLineAngleDeg: Int
    public var currentCrossLinePosition: Int
    public var crossLineRenderData: GLDataFmCrossLine?

    public init() {
        self.currentCrossLineAngleDeg = 0
        self.currentCrossLinePosition = 0
        self.crossLineRenderData = nil
    }

    public func clear() {
        currentCrossLineAngleDeg = 0
        currentCrossLinePosition = 0
        crossLineRenderData = nil
    }

    public func getCrossLineRenderData() -> GLDataFmCrossLine? {
        crossLineRenderData
    }

    public func getCurrentCrossLineAngleDeg() -> Int {
        currentCrossLineAngleDeg
    }

    public func getCurrentCrossLinePosition() -> Int {
        currentCrossLinePosition
    }

    public func getNew(_ foldedModel: FoldedModel) {
        currentCrossLineAngleDeg = foldedModel.crossLine.getAngleDegDefaultMagnitude()
        currentCrossLinePosition = foldedModel.crossLine.getPositionDefaultMagnitude()
        crossLineRenderData = GLDataFmCrossLine.getRenderData(
            foldedModel.mFaces,
            foldedModel.crossLine,
            foldedModel.crossLine.getAngleDegDefaultMagnitude(),
            foldedModel.crossLine.getPositionDefaultMagnitude())
    }

    public func updateCrossLineRenderData(_ foldedModel: FoldedModel, angleDeg: Int, position: Int) {
        crossLineRenderData = GLDataFmCrossLine.getRenderData(
            foldedModel.mFaces, foldedModel.crossLine, angleDeg, position)
        currentCrossLineAngleDeg = angleDeg
        currentCrossLinePosition = position
    }
}

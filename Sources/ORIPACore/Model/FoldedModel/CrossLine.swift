// Port of `com.origamitoolbox.oripa.model.foldedmodel.CrossLine`
// (oripa-port src/js/core/model/foldedmodel/CrossLine.js).
//
// The cut line used by the fold "cross line" view. Java builds a 4x4 matrix
// (identity -> rotate around z -> translate on y) and transforms the two endpoints
// (-halfLength, 0) / (halfLength, 0) with GLUtil.getTransformedPointDouble; the JS port uses the
// equivalent closed form, kept here.
import Foundation

public final class CrossLine {
    public let foldedModelHalfSize: Double
    public let maxCrossLinePositionMultiple = 3
    public let maxCrossLineLengthMultiple = 3
    public let maxCrossLineAngleDeg = 360

    /// Java package-private `CrossLine(double)`.
    public init(_ foldedModelHalfSize: Double) {
        self.foldedModelHalfSize = foldedModelHalfSize
    }

    /// Labelled convenience for the same constructor (JS `new CrossLine(halfSize)`).
    public convenience init(foldedModelHalfSize: Double) {
        self.init(foldedModelHalfSize)
    }

    /// Java `private float getCrossLineHalfLength()`; the JS reference returns a JS number.
    public func getCrossLineHalfLength() -> Double {
        (foldedModelHalfSize * 3.0) / 2.0
    }

    public func getAngleDegDefaultMagnitude() -> Int {
        Constant.SINGLE_GRID_IMAGE_DIMEN_DP
    }

    public func getAngleDegMaxMagnitude() -> Int {
        360
    }

    /// Java: `Matrix.rotateM(angleDeg around z)` then `translateM(0, pos - posMax/2)`
    /// applied to (+-halfLength, 0); closed-form equivalent as in the JS port.
    public func getFmCrossLine(angleDeg: Int, position: Int) -> Segment<PointDouble> {
        let halfLength = getCrossLineHalfLength()
        let positionMaxMagnitude = getPositionMaxMagnitude()
        let offsetY = Double(position) - (Double(positionMaxMagnitude) / 2.0)
        let rad = (Double(angleDeg) * Double.pi) / 180.0
        let c = cos(rad)
        let s = sin(rad)
        let start = PointDouble((-halfLength * c) - (offsetY * s), (-halfLength * s) + (offsetY * c))
        let end = PointDouble((halfLength * c) - (offsetY * s), (halfLength * s) + (offsetY * c))
        return Segment<PointDouble>(start, end)
    }

    public func getPositionDefaultMagnitude() -> Int {
        Int((foldedModelHalfSize * 3.0) / 2.0)
    }

    public func getPositionMaxMagnitude() -> Int {
        Int(foldedModelHalfSize) * 3
    }

    public func getPositionMinMagnitude() -> Int {
        0
    }
}

// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.GridTriangleLines`
// (oripa-port src/js/core/model/creasepattern/grid/GridTriangleLines.js).
import Foundation

public final class GridTriangleLines: AbstractGridLines {
    private static let PI = 3.141592653589793
    private static let HALF_PI = 1.5707963267948966
    private static let ONE_THIRD_PI = 1.0471975511965976
    private static let TAN_30_DEG = 0.5235987755982988

    /// JS `Math.sign`.
    private static func sign(_ value: Double) -> Double {
        if value > 0 { return 1.0 }
        if value < 0 { return -1.0 }
        return value  // 0 or NaN
    }

    private func getNearestLine(_ pointDouble: PointDouble, _ d: Double, _ z: Bool,
                                _ d2: Double, _ d3: Double, _ i: Int, _ i2: Int,
                                _ d4: Double) -> NearestItem<Segment<PointDouble>> {
        let radians = d4 * GridTriangleLines.PI / 180.0
        let d6 = 2.0 * d2
        let perpendicularIntersect = GeomUtil.getPerpendicularIntersect(
            PointDouble((-cos(radians)) * d6, (-sin(radians)) * d6),
            PointDouble(cos(radians) * d6, d6 * sin(radians)),
            pointDouble
        )
        let dSignum = GridTriangleLines.sign(pointDouble.y - perpendicularIntersect.y)
            * GeomUtil.getDistance(perpendicularIntersect, pointDouble)
        let iFloor = Int(floor((dSignum - d) / d3))
        let iCeil = Int(ceil((dSignum + d) / d3))
        let iConstrain = GeomUtil.constrain(iFloor, i, i2)
        let iConstrain2 = GeomUtil.constrain(iCeil, i, i2)
        var nearestItem = NearestItem<Segment<PointDouble>>()
        var row = iConstrain
        while row <= iConstrain2 {
            let d5: Double
            if z {
                d5 = Double(row) * d3
            } else {
                d5 = (Double(row) + 0.5) * d3
            }
            let angle = GridTriangleLines.HALF_PI + radians
            let pointDouble2 = PointDouble(cos(angle) * d5, sin(angle) * d5)
            let dAbs = (d2 - abs(d5)) * tan(GridTriangleLines.TAN_30_DEG)
            let segment = Segment(
                PointDouble(pointDouble2.x + ((-cos(radians)) * dAbs),
                            pointDouble2.y + ((-sin(radians)) * dAbs)),
                PointDouble(pointDouble2.x + (cos(radians) * dAbs),
                            pointDouble2.y + (dAbs * sin(radians)))
            )
            let minDistance = segment.getMinDistance(pointDouble)
            if minDistance < nearestItem.distance {
                nearestItem = NearestItem(segment, minDistance)
            }
            row += 1
        }
        return nearestItem
    }

    public override func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        let boxHalfSideLength = getBoxHalfSideLength()
        if !GeomUtil.isPointInOriginHexagon(pointDouble, Double(boxHalfSideLength), d) {
            return NearestItem()
        }
        let divisionNumber = getDivisionNumber()
        let z = divisionNumber % 2 == 0
        let dSqrt = Double(boxHalfSideLength) * sqrt(3.0)
        let d3 = dSqrt / Double(divisionNumber)
        let i = Int(floor(Double(divisionNumber) / 2))
        let i2 = z ? -i : (-i) - 1
        let dArr: [Double] = [0.0, 60.0, -60.0]
        var nearestItem = NearestItem<Segment<PointDouble>>()
        for d4 in dArr {
            let nearestLine = getNearestLine(pointDouble, d, z, dSqrt, d3, i2, i, d4)
            if nearestLine.distance < nearestItem.distance {
                nearestItem = nearestLine
            }
        }
        guard let nearestSegment = nearestItem.nearestItem,
              !(nearestItem.distance > d) else { return NearestItem() }
        return NearestItem(
            OriLine(OriPoint(nearestSegment.start), OriPoint(nearestSegment.end), LineType.grid.rawValue),
            nearestItem.distance
        )
    }

    public override func makeRenderData() -> GridRenderData {
        let boxHalfSideLength = Double(getBoxHalfSideLength())
        let divisionNumber = getDivisionNumber()
        let i = (divisionNumber + 1) * 3
        let d = 3.0
        let dSqrt = boxHalfSideLength * sqrt(3.0)
        let d3 = dSqrt / Double(divisionNumber)
        var floats = [Float](repeating: 0.0, count: i * 2 * 4)
        var angles = [Int16](repeating: 0, count: i * 4)
        var indices = [Int16](repeating: 0, count: i * 6)
        let pointDouble = PointDouble(0.0, 0.0)
        for i2 in 0...divisionNumber {
            let d5 = (Double(i2) * d3) - (dSqrt / 2.0)
            let dAbs = (dSqrt - abs(d5)) / sqrt(d)
            let pointDouble2 = PointDouble(-dAbs, d5)
            let pointDouble3 = PointDouble(dAbs, d5)
            let i3 = i2 * 3
            let i4 = i3 * 4
            let i5 = i4 * 2
            floats[i5] = Float(pointDouble2.x)
            floats[i5 + 1] = Float(pointDouble2.y)
            floats[i5 + 2] = Float(pointDouble2.x)
            floats[i5 + 3] = Float(pointDouble2.y)
            floats[i5 + 4] = Float(pointDouble3.x)
            floats[i5 + 5] = Float(pointDouble3.y)
            floats[i5 + 6] = Float(pointDouble3.x)
            floats[i5 + 7] = Float(pointDouble3.y)
            let angleRadians = GeomUtil.getAngleRadians(pointDouble, pointDouble2) + GridTriangleLines.ONE_THIRD_PI
            let angleRadians2 = GeomUtil.getAngleRadians(pointDouble, pointDouble3) + GridTriangleLines.ONE_THIRD_PI
            let angleRadians3 = GeomUtil.getAngleRadians(pointDouble, pointDouble2) - GridTriangleLines.ONE_THIRD_PI
            let angleRadians4 = GeomUtil.getAngleRadians(pointDouble, pointDouble3) - GridTriangleLines.ONE_THIRD_PI
            let length = pointDouble2.length()
            floats[i5 + 8] = Float(length * cos(angleRadians))
            floats[i5 + 9] = Float(sin(angleRadians) * length)
            floats[i5 + 10] = Float(cos(angleRadians) * length)
            floats[i5 + 11] = Float(sin(angleRadians) * length)
            floats[i5 + 12] = Float(cos(angleRadians2) * length)
            floats[i5 + 13] = Float(sin(angleRadians2) * length)
            floats[i5 + 14] = Float(cos(angleRadians2) * length)
            floats[i5 + 15] = Float(sin(angleRadians2) * length)
            floats[i5 + 16] = Float(cos(angleRadians3) * length)
            floats[i5 + 17] = Float(sin(angleRadians3) * length)
            floats[i5 + 18] = Float(cos(angleRadians3) * length)
            floats[i5 + 19] = Float(sin(angleRadians3) * length)
            floats[i5 + 20] = Float(cos(angleRadians4) * length)
            floats[i5 + 21] = Float(sin(angleRadians4) * length)
            floats[i5 + 22] = Float(cos(angleRadians4) * length)
            floats[i5 + 23] = Float(sin(angleRadians4) * length)
            let i6 = i3 * 6
            indices[i6] = Int16(clamping: i4)
            indices[i6 + 1] = Int16(clamping: i4 + 1)
            indices[i6 + 2] = Int16(clamping: i4 + 3)
            indices[i6 + 3] = Int16(clamping: i4 + 1)
            indices[i6 + 4] = Int16(clamping: i4 + 2)
            indices[i6 + 5] = Int16(clamping: i4 + 3)
            indices[i6 + 6] = Int16(clamping: i4 + 4)
            indices[i6 + 7] = Int16(clamping: i4 + 5)
            indices[i6 + 8] = Int16(clamping: i4 + 7)
            indices[i6 + 9] = Int16(clamping: i4 + 5)
            indices[i6 + 10] = Int16(clamping: i4 + 6)
            indices[i6 + 11] = Int16(clamping: i4 + 7)
            indices[i6 + 12] = Int16(clamping: i4 + 8)
            indices[i6 + 13] = Int16(clamping: i4 + 9)
            indices[i6 + 14] = Int16(clamping: i4 + 11)
            indices[i6 + 15] = Int16(clamping: i4 + 9)
            indices[i6 + 16] = Int16(clamping: i4 + 10)
            indices[i6 + 17] = Int16(clamping: i4 + 11)
            angles[i4] = 900
            angles[i4 + 1] = -900
            angles[i4 + 2] = -900
            angles[i4 + 3] = 900
            angles[i4 + 4] = 1500
            angles[i4 + 5] = -300
            angles[i4 + 6] = -300
            angles[i4 + 7] = 1500
            angles[i4 + 8] = 300
            angles[i4 + 9] = -1500
            angles[i4 + 10] = -1500
            angles[i4 + 11] = 300
        }
        return GridRenderData(floats, angles, indices)
    }
}

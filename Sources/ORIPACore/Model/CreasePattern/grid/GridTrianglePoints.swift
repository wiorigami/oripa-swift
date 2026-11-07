// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.GridTrianglePoints`
// (oripa-port src/js/core/model/creasepattern/grid/GridTrianglePoints.js).
//
// The decompiled `i4 == 0` else branch has a stale `pointDouble2` fall-through; the JS port
// reconstructed it as "this grid point does not exist -> skip" (see docs/reports/core-model.md).
import Foundation

public final class GridTrianglePoints: AbstractGridPoints {
    public override func findPoint(_ pointDouble: PointDouble, _ d: Double,
                                   _ d2: Double) -> NearestItem<OriPoint> {
        if !GeomUtil.isPointInOriginHexagon(pointDouble, d2, d) {
            return NearestItem()
        }
        var divisionNumber = getDivisionNumber()
        let z = divisionNumber % 2 == 0
        if !z { divisionNumber *= 2 }
        let dSqrt = sqrt(3.0) * d2
        let d4 = dSqrt / Double(divisionNumber)
        let i2 = Int(floor(Double(divisionNumber) / 2))
        let i3 = z ? -i2 : (-i2) - 1
        let iFloor = Int(floor((pointDouble.y - d) / d4))
        let iCeil = Int(ceil((pointDouble.y + d) / d4))
        let iConstrain = GeomUtil.constrain(iFloor, i3, i2)
        let iConstrain2 = GeomUtil.constrain(iCeil, i3, i2)
        let d5 = (d2 * 2.0) / Double(divisionNumber)
        let iFloor2 = Int(floor((pointDouble.x - d) / d5))
        let iCeil2 = Int(ceil((pointDouble.x + d) / d5))
        var nearestItem = NearestItem<PointDouble>()
        var row = iConstrain
        while row <= iConstrain2 {
            let iAbs = Int(floor(Double(divisionNumber - abs(row)) / 2))
            let i4 = row % 2
            let i5 = i4 == 0 ? -iAbs : (-iAbs) - 1
            var nearestRow = nearestItem
            var column = GeomUtil.constrain(iFloor2, i5, iAbs)
            while column <= GeomUtil.constrain(iCeil2, i5, iAbs) {
                if i4 == 0 {
                    let i = Int(floor(Double(row) / 2)) % 2
                    // Java: z || (!((i == 0) && k even) && (i == 0 || k even)).
                    let accept = z || ((!((i == 0) && (column % 2 == 0))) && (i == 0 || (column % 2 == 0)))
                    if !accept {
                        column += 1
                        continue
                    }
                    let pointDouble2 = PointDouble(Double(column) * d5, Double(row) * d4)
                    let minDistance = pointDouble2.getMinDistance(pointDouble)
                    if minDistance < nearestRow.distance {
                        nearestRow = NearestItem(pointDouble2, minDistance)
                    }
                } else {
                    let pointDouble2 = PointDouble((Double(column) + 0.5) * d5, Double(row) * d4)
                    let minDistance = pointDouble2.getMinDistance(pointDouble)
                    if minDistance < nearestRow.distance {
                        nearestRow = NearestItem(pointDouble2, minDistance)
                    }
                }
                column += 1
            }
            row += 1
            nearestItem = nearestRow
        }
        if nearestItem.distance > d || nearestItem.nearestItem == nil {
            return NearestItem()
        }
        return NearestItem(OriPoint(nearestItem.nearestItem!), nearestItem.distance)
    }
}

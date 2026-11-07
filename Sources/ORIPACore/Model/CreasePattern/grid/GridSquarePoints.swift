// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.GridSquarePoints`
// (oripa-port src/js/core/model/creasepattern/grid/GridSquarePoints.js).
import Foundation

public final class GridSquarePoints: AbstractGridPoints {
    public override func findPoint(_ pointDouble: PointDouble, _ d: Double,
                                   _ d2: Double) -> NearestItem<OriPoint> {
        // `d2` is the box half side length (Java passes the CreasePattern half size).
        if GeomUtil.isPointOutsideOriginSquare(pointDouble, d2, d) {
            return NearestItem()
        }
        let divisionNumber = getDivisionNumber()
        let z = divisionNumber % 2 == 0
        let d4 = (d2 * 2.0) / Double(divisionNumber)
        let i = Int(floor(Double(divisionNumber) / 2))
        let i2 = z ? -i : (-i) - 1
        let iFloor = Int(floor((pointDouble.x - d) / d4))
        let iFloor2 = Int(floor((pointDouble.y - d) / d4))
        let iCeil = Int(ceil((pointDouble.x + d) / d4))
        let iCeil2 = Int(ceil((pointDouble.y + d) / d4))
        let iConstrain = GeomUtil.constrain(iFloor, i2, i)
        let iConstrain2 = GeomUtil.constrain(iFloor2, i2, i)
        let iConstrain3 = GeomUtil.constrain(iCeil, i2, i)
        let iConstrain4 = GeomUtil.constrain(iCeil2, i2, i)
        var nearestItem = NearestItem<PointDouble>()
        var row = iConstrain
        while row <= iConstrain3 {
            var column = iConstrain2
            var nearestRow = nearestItem
            while column <= iConstrain4 {
                let pointDouble2: PointDouble
                if z {
                    pointDouble2 = PointDouble(Double(row) * d4, Double(column) * d4)
                } else {
                    pointDouble2 = PointDouble((Double(row) + 0.5) * d4, (Double(column) + 0.5) * d4)
                }
                let minDistance = pointDouble2.getMinDistance(pointDouble)
                if minDistance < nearestRow.distance {
                    nearestRow = NearestItem(pointDouble2, minDistance)
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

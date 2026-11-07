// Port of `com.origamitoolbox.oripa.model.creasepattern.grid.GridSquareLines`
// (oripa-port src/js/core/model/creasepattern/grid/GridSquareLines.js).
import Foundation

public final class GridSquareLines: AbstractGridLines {
    public override func findLine(_ pointDouble: PointDouble, _ d: Double) -> NearestItem<OriLine> {
        let boxHalfSideLength = getBoxHalfSideLength()
        if GeomUtil.isPointOutsideOriginSquare(pointDouble, Double(boxHalfSideLength), d) {
            return NearestItem()
        }
        let divisionNumber = getDivisionNumber()
        let z = divisionNumber % 2 == 0
        let d3 = (2.0 * Double(boxHalfSideLength)) / Double(divisionNumber)
        let i = Int(floor(Double(divisionNumber) / 2))
        let i2 = z ? -i : (-i) - 1
        let iFloor = Int(floor((pointDouble.x - d) / d3))
        let iFloor2 = Int(floor((pointDouble.y - d) / d3))
        let iCeil = Int(ceil((pointDouble.x + d) / d3))
        let iCeil2 = Int(ceil((pointDouble.y + d) / d3))
        let iConstrain = GeomUtil.constrain(iFloor, i2, i)
        let iConstrain2 = GeomUtil.constrain(iFloor2, i2, i)
        let iConstrain3 = GeomUtil.constrain(iCeil2, i2, i)
        var nearestItem = NearestItem<Segment<PointDouble>>()
        var row = iConstrain
        while row <= GeomUtil.constrain(iCeil, i2, i) {
            let segment: Segment<PointDouble>
            if z {
                let d5 = Double(row) * d3
                segment = Segment(PointDouble(d5, -Double(boxHalfSideLength)),
                                  PointDouble(d5, Double(boxHalfSideLength)))
            } else {
                let d7 = (Double(row) + 0.5) * d3
                segment = Segment(PointDouble(d7, -Double(boxHalfSideLength)),
                                  PointDouble(d7, Double(boxHalfSideLength)))
            }
            let minDistance = segment.getMinDistance(pointDouble)
            if minDistance < nearestItem.distance {
                nearestItem = NearestItem(segment, minDistance)
            }
            row += 1
        }
        var column = iConstrain2
        while column <= iConstrain3 {
            let segment: Segment<PointDouble>
            if z {
                let d9 = Double(column) * d3
                segment = Segment(PointDouble(-Double(boxHalfSideLength), d9),
                                  PointDouble(Double(boxHalfSideLength), d9))
            } else {
                let d11 = (Double(column) + 0.5) * d3
                segment = Segment(PointDouble(-Double(boxHalfSideLength), d11),
                                  PointDouble(Double(boxHalfSideLength), d11))
            }
            let minDistance2 = segment.getMinDistance(pointDouble)
            if minDistance2 < nearestItem.distance {
                nearestItem = NearestItem(segment, minDistance2)
            }
            column += 1
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
        let i = (divisionNumber + 1) * 2
        let d2 = (2.0 * boxHalfSideLength) / Double(divisionNumber)
        let f = boxHalfSideLength
        var floats = [Float](repeating: 0.0, count: i * 2 * 4)
        var angles = [Int16](repeating: 0, count: i * 4)
        var indices = [Int16](repeating: 0, count: i * 6)
        for i2 in 0...divisionNumber {
            let f2 = (Double(i2) * d2) - boxHalfSideLength
            let i3 = i2 * 2
            let i4 = i3 * 4
            let i5 = i4 * 2
            floats[i5] = Float(f2)
            floats[i5 + 1] = Float(-f)
            floats[i5 + 2] = Float(f2)
            floats[i5 + 3] = Float(-f)
            floats[i5 + 4] = Float(f2)
            floats[i5 + 5] = Float(f)
            floats[i5 + 6] = Float(f2)
            floats[i5 + 7] = Float(f)
            floats[i5 + 8] = Float(-f)
            floats[i5 + 9] = Float(f2)
            floats[i5 + 10] = Float(-f)
            floats[i5 + 11] = Float(f2)
            floats[i5 + 12] = Float(f)
            floats[i5 + 13] = Float(f2)
            floats[i5 + 14] = Float(f)
            floats[i5 + 15] = Float(f2)
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
            angles[i4] = 1800
            angles[i4 + 1] = 0
            angles[i4 + 2] = 0
            angles[i4 + 3] = 1800
            angles[i4 + 4] = 900
            angles[i4 + 5] = -900
            angles[i4 + 6] = -900
            angles[i4 + 7] = 900
        }
        return GridRenderData(floats, angles, indices)
    }
}

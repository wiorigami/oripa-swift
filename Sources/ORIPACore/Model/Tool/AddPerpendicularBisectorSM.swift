// Port of `com.origamitoolbox.oripa.model.tool.AddPerpendicularBisectorSM`
// (oripa-port src/js/core/model/tool/AddPerpendicularBisectorSM.js).
//
// "Perpendicular Bisector": picks two points and two lines; draws the perpendicular bisector of
// the point pair between the two intersection points with the picked lines.
import Foundation

public final class AddPerpendicularBisectorSM: PointsAndLinesStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_PERPENDICULAR_BISECTOR.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 2,
            lineAcceptedCount: 2
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        var i = 0
        let pointDoubleArr = getState().pointsPicked.toArray()
        let pointDouble = PointDouble(
            (pointDoubleArr[0].x + pointDoubleArr[1].x) / 2.0,
            (pointDoubleArr[0].y + pointDoubleArr[1].y) / 2.0
        )
        let angleRadians = GeomUtil.getAngleRadians(pointDoubleArr[0], pointDoubleArr[1])
            + (Double.pi / 2.0)
        let pointDouble2 = PointDouble(
            pointDouble.x - cos(angleRadians),
            pointDouble.y - sin(angleRadians)
        )
        let pointDouble3 = PointDouble(
            pointDouble.x + cos(angleRadians),
            pointDouble.y + sin(angleRadians)
        )
        let hashSet = JavaSet<OriPoint>()
        let iterator = getState().linesPicked.iterator()
        while iterator.hasNext() {
            let oriLine = iterator.next()
            if let lineIntersect = GeomUtil.getLineIntersect(
                pointDouble2, pointDouble3, oriLine.start, oriLine.end
            ) {
                hashSet.add(OriPoint(lineIntersect))
            }
        }
        let historyGroup = HistoryGroup(getToolType())
        if hashSet.size() == 2 {
            let arrayList = hashSet.values()
            historyGroup.add(addNewLine(cp, arrayList[0], arrayList[1]))
        } else if hashSet.size() > 2 {
            let arrayList2 = hashSet.values()
            var oriPoint: OriPoint?
            var d = -Double.greatestFiniteMagnitude
            var oriPoint2: OriPoint?
            while i < hashSet.size() {
                let i2 = i + 1
                var oriPoint3 = oriPoint2
                var i3 = i2
                while i3 < hashSet.size() {
                    let distance = GeomUtil.getDistance(arrayList2[i], arrayList2[i3])
                    if distance > d {
                        oriPoint = arrayList2[i]
                        oriPoint3 = arrayList2[i3]
                        d = distance
                    }
                    i3 += 1
                }
                i = i2
                oriPoint2 = oriPoint3
            }
            if let oriPoint, let oriPoint2 {
                historyGroup.add(addNewLine(cp, oriPoint, oriPoint2))
            }
        }
        return historyGroup
    }

    public override func getNew() -> CpStateMachine {
        AddPerpendicularBisectorSM(getDirectSelectionEnabled())
    }
}

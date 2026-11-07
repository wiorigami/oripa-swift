// Port of `com.origamitoolbox.oripa.model.tool.AddLineSM`
// (oripa-port src/js/core/model/tool/AddLineSM.js).
//
// "Add Line": picks two points and two lines; draws the segment between the two intersection
// points of the point-to-point line with the picked lines. With >2 intersections the farthest
// pair is used (same scan order as the reference).
import Foundation

public final class AddLineSM: PointsAndLinesStateMachine {
    public init(_ directSelectionEnabled: Bool) {
        super.init(
            toolType: CpToolType.ADD_LINE.rawValue,
            directSelectionEnabled: directSelectionEnabled,
            pointAcceptedCount: 2,
            lineAcceptedCount: 2
        )
    }

    public override func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        var i = 0
        let pointDoubleArr = getState().pointsPicked.toArray()
        let hashSet = JavaSet<OriPoint>()
        let iterator = getState().linesPicked.iterator()
        while iterator.hasNext() {
            let oriLine = iterator.next()
            if let lineIntersect = GeomUtil.getLineIntersect(
                pointDoubleArr[0], pointDoubleArr[1], oriLine.start, oriLine.end
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
        AddLineSM(getDirectSelectionEnabled())
    }
}

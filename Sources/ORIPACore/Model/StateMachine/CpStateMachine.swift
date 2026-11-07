// Port of `com.origamitoolbox.oripa.model.statemachine.CpStateMachine`
// (oripa-port src/js/core/model/statemachine/CpStateMachine.js).
//
// Abstract base class for every tool state machine: owns the shared `CpState`, the
// `directSelectionEnabled`/`toolType` flags and the line-insertion algorithm that splits
// intersecting/overlapping lines while recording what changed for undo/redo.
import Foundation

open class CpStateMachine: BasicCpStateMachine {
    /// Java `private final boolean directSelectionEnabled`.
    public let directSelectionEnabled: Bool

    /// Java `final CpState state` (package private in Java; a plain field in the JS port).
    public let state: CpState

    /// Java `private final byte toolType`.
    private let toolType: Int

    init(toolType: Int, directSelectionEnabled: Bool) {
        self.directSelectionEnabled = directSelectionEnabled
        self.state = CpState()
        self.toolType = toolType
    }

    // MARK: - Line insertion (Java protected addNewLine overloads)

    /// Java `protected HistoryItem addNewLine(CreasePattern, PointDouble, PointDouble)`:
    /// inserts using the crease pattern's current input line type.
    public func addNewLine(
        _ creasePattern: CreasePattern,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble
    ) -> HistoryItem {
        addNewLine(creasePattern, pointDouble, pointDouble2, creasePattern.inputLineType)
    }

    /// Java `protected HistoryItem addNewLine(CreasePattern, PointDouble, PointDouble, byte)`.
    ///
    /// Splits every line crossing/overlapping the new segment, drops duplicate diagonal lines and
    /// records removed/added/type-changed lines in a `HistoryItem`. 1:1 port of the reference
    /// algorithm (same iteration order, same `containsInRange` guards, same sort of intersection
    /// points before building the replacement segments).
    public func addNewLine(
        _ creasePattern: CreasePattern,
        _ pointDouble: PointDouble,
        _ pointDouble2: PointDouble,
        _ b: LineType
    ) -> HistoryItem {
        var arrayList: [OriPoint] = []
        let hashSet = JavaSet<OriLine>()
        let hashSet2 = JavaSet<OriLine>()
        let oriLine = OriLine(OriPoint(pointDouble), OriPoint(pointDouble2), b)
        let historyItem = HistoryItem()

        if creasePattern.lineMVFB.contains(oriLine) {
            if let oriLineFindExact = creasePattern.lineMVFB.findExact(oriLine),
               oriLine.type() != oriLineFindExact.type() {
                historyItem.changeLines.append(
                    HistoryTypeChange(oriLineFindExact, oriLineFindExact.type(), b)
                )
                oriLineFindExact.setType(b)
            }
            return historyItem
        }

        let linesInRange = creasePattern.lineMVFB.findAllLinesInRange(oriLine.start, oriLine.end)
        let iterator = linesInRange.iterator()
        while iterator.hasNext() {
            let oriLine2 = iterator.next()
            if let lineIntersect = GeomUtil.getLineIntersect(
                oriLine2.start, oriLine2.end, oriLine.start, oriLine.end
            ) {
                let oriPoint = OriPoint(lineIntersect)
                if oriLine2.containsInRange(oriPoint) && oriLine.containsInRange(oriPoint)
                    && !oriLine.start.equals(oriLine2.start)
                    && !oriLine.start.equals(oriLine2.end)
                    && !oriLine.end.equals(oriLine2.start)
                    && !oriLine.end.equals(oriLine2.end)
                {
                    if !oriLine2.start.equals(oriPoint) {
                        hashSet.add(OriLine(oriLine2.start, oriPoint, oriLine2.type()))
                    }
                    if !oriLine2.end.equals(oriPoint) {
                        hashSet.add(OriLine(oriPoint, oriLine2.end, oriLine2.type()))
                    }
                    arrayList.append(oriPoint)
                    hashSet2.add(oriLine2)
                }
            } else if GeomUtil.isCollinear(
                oriLine2.start, oriLine2.end, oriLine.start, oriLine.end
            ) {
                if oriLine.containsInRange(oriLine2.start) && oriLine.containsInRange(oriLine2.end) {
                    hashSet2.add(oriLine2)
                } else if oriLine2.containsInRange(oriLine.start)
                            || oriLine2.containsInRange(oriLine.end)
                {
                    if !oriLine.start.equals(oriLine2.end) && !oriLine.end.equals(oriLine2.start) {
                        if oriLine2.start.compareTo(oriLine.start) < 0 {
                            hashSet.add(OriLine(oriLine2.start, oriLine.start, oriLine2.type()))
                        }
                        if oriLine2.end.compareTo(oriLine.end) > 0 {
                            hashSet.add(OriLine(oriLine.end, oriLine2.end, oriLine2.type()))
                        }
                        hashSet2.add(oriLine2)
                    }
                }
            }
        }

        arrayList.append(oriLine.start)
        arrayList.append(oriLine.end)
        arrayList.sort { $0.compareTo($1) < 0 }
        if arrayList.count > 1 {
            for i in 1..<arrayList.count {
                let i2 = i - 1
                if !arrayList[i2].equals(arrayList[i]) {
                    hashSet.add(OriLine(arrayList[i2], arrayList[i], b))
                }
            }
        }

        let oldIterator = hashSet2.iterator()
        while oldIterator.hasNext() {
            let oldLine = oldIterator.next()
            historyItem.oldLines.append(oldLine)
            creasePattern.removeLine(oldLine)
        }

        let newIterator = hashSet.iterator()
        while newIterator.hasNext() {
            let oriLine4 = newIterator.next()
            if creasePattern.lineMVFB.contains(oriLine4) {
                if let oriLineFindExact2 = creasePattern.lineMVFB.findExact(oriLine4),
                   oriLine4.type() != oriLineFindExact2.type() {
                    historyItem.changeLines.append(
                        HistoryTypeChange(oriLineFindExact2, oriLineFindExact2.type(), b)
                    )
                    oriLineFindExact2.setType(b)
                }
            } else if !creasePattern.lineMVFB.contains(oriLine4.diagonalCopy()) {
                historyItem.newLines.append(creasePattern.addLineNoCheck(oriLine4))
            }
        }
        return historyItem
    }

    // MARK: - Batch operations (Java public + protected Set overloads)

    /// Java `doBatchLineOperation(Context, CreasePattern, OriPoint, OriPoint)`: selects the lines
    /// inside/intersecting the drag rectangle, then delegates to `doBatchLineOperationSet`.
    public func doBatchLineOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup {
        if !hasBatchLineOperation() {
            return HistoryGroup(getToolType())
        }
        let oriPoint3 = OriPoint(start.x, end.y)
        let oriPoint4 = OriPoint(end.x, start.y)
        let oriLineArr = [
            OriLine(start, oriPoint3, LineType.undefined),
            OriLine(start, oriPoint4, LineType.undefined),
            OriLine(end, oriPoint3, LineType.undefined),
            OriLine(end, oriPoint4, LineType.undefined),
        ]
        let oriLine = OriLine(start, end, LineType.undefined)
        let hashSet = JavaSet<OriLine>()
        let lines = cp.lineMVFB.findAllLinesInRange(start, end)
        let iterator = lines.iterator()
        while iterator.hasNext() {
            let oriLine2 = iterator.next()
            if oriLine.containsInRange(oriLine2.start) || oriLine.containsInRange(oriLine2.end) {
                hashSet.add(oriLine2)
            } else {
                var intersects = false
                for oriLine3 in oriLineArr {
                    if GeomUtil.getSegmentIntersect(
                        oriLine3.start, oriLine3.end, oriLine2.start, oriLine2.end
                    ) != nil {
                        intersects = true
                        break
                    }
                }
                if intersects {
                    hashSet.add(oriLine2)
                }
            }
        }
        return doBatchLineOperationSet(context, cp, hashSet)
    }

    /// Java's `protected HistoryGroup doBatchLineOperation(Context, CreasePattern, Set<OriLine>)`
    /// overload; subclasses override this hook. (The JS port names it `...Set` because JS has no
    /// method overloading.)
    open func doBatchLineOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriLine>
    ) -> HistoryGroup {
        HistoryGroup(getToolType())
    }

    /// Java `doBatchPointOperation(Context, CreasePattern, OriPoint, OriPoint)`.
    public func doBatchPointOperation(
        context: CpContext?,
        cp: CreasePattern,
        start: OriPoint,
        end: OriPoint
    ) -> HistoryGroup {
        if !hasBatchPointOperation() {
            return HistoryGroup(getToolType())
        }
        return doBatchPointOperationSet(
            context, cp, cp.pointMVFB.findAllPointsInRange(start, end)
        )
    }

    /// Java's protected `doBatchPointOperation(Context, CreasePattern, Set<OriPoint>)` overload.
    open func doBatchPointOperationSet(
        _ context: CpContext?,
        _ creasePattern: CreasePattern,
        _ set: JavaSet<OriPoint>
    ) -> HistoryGroup {
        HistoryGroup(getToolType())
    }

    // MARK: - Transitions

    /// Java `doLongTransition`: NO_CHANGE unless the machine overrides it (only AddMirroredLinesSM).
    public func doLongTransition(
        creasePattern: CreasePattern,
        z: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int {
        CpTransitionResult.NO_CHANGE.rawValue
    }

    /// Java `doTransition`: dispatches to the direct/indirect selection flow.
    public func doTransition(
        creasePattern: CreasePattern,
        snap: Bool,
        pointDouble: PointDouble,
        radius: Double
    ) -> Int {
        directSelectionEnabled
            ? doDirectTransition(creasePattern, snap, pointDouble, radius)
            : doIndirectTransition(creasePattern, snap, pointDouble, radius)
    }

    /// Java `abstract byte doDirectTransition(...)`.
    open func doDirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        fatalError("abstract: doDirectTransition")
    }

    /// Java `abstract byte doIndirectTransition(...)`.
    open func doIndirectTransition(
        _ creasePattern: CreasePattern,
        _ z: Bool,
        _ pointDouble: PointDouble,
        _ d: Double
    ) -> Int {
        fatalError("abstract: doIndirectTransition")
    }

    // MARK: - Lifecycle / accessors

    /// Java `abstract HistoryGroup finish(Context, CreasePattern)`.
    open func finish(context: CpContext?, cp: CreasePattern) -> HistoryGroup {
        fatalError("abstract: finish")
    }

    /// Java `abstract CpStateMachine getNew()`.
    open func getNew() -> CpStateMachine {
        fatalError("abstract: getNew")
    }

    public func getDirectSelectionEnabled() -> Bool { directSelectionEnabled }
    public func getState() -> CpState { state }
    public func getToolType() -> Int { toolType }
    public func hasBatchLineOperation() -> Bool { false }
    public func hasBatchPointOperation() -> Bool { false }
}

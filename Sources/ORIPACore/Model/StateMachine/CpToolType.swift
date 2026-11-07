// Port of `com.origamitoolbox.oripa.model.statemachine.CpToolType`
// (oripa-port src/js/core/model/statemachine/CpToolType.js).
//
// Java `byte` constants. The Swift enum keeps the exact numeric values; the Java constant
// names are available as aliases because the reference call sites and tests use them
// (`CpToolType.ADD_SEGMENT`, ...).
import Foundation

public enum CpToolType: Int, CaseIterable, Sendable {
    case addSegment = 0
    case addLine = 1
    case addPerpendicularBisector = 2
    case addAngleBisector = 3
    case addTriangleIncenter = 4
    case addPerpendicularSegment = 5
    case addSymmetricalSegment = 6
    case addLineExtension = 7
    case addMirroredLines = 8
    case addSegmentByValue = 9
    case changeLine = 10
    case selectLine = 11
    case deleteLine = 12
    case deleteVertex = 13

    // MARK: - Java constant names

    public static let ADD_ANGLE_BISECTOR = CpToolType.addAngleBisector
    public static let ADD_LINE = CpToolType.addLine
    public static let ADD_LINE_EXTENSION = CpToolType.addLineExtension
    public static let ADD_MIRRORED_LINES = CpToolType.addMirroredLines
    public static let ADD_PERPENDICULAR_BISECTOR = CpToolType.addPerpendicularBisector
    public static let ADD_PERPENDICULAR_SEGMENT = CpToolType.addPerpendicularSegment
    public static let ADD_SEGMENT = CpToolType.addSegment
    public static let ADD_SEGMENT_BY_VALUE = CpToolType.addSegmentByValue
    public static let ADD_SYMMETRICAL_SEGMENT = CpToolType.addSymmetricalSegment
    public static let ADD_TRIANGLE_INCENTER = CpToolType.addTriangleIncenter
    public static let CHANGE_LINE = CpToolType.changeLine
    public static let DELETE_LINE = CpToolType.deleteLine
    public static let DELETE_VERTEX = CpToolType.deleteVertex
    public static let SELECT_LINE = CpToolType.selectLine
}

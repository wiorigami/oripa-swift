// Port of `com.origamitoolbox.oripa.resource.GridType` (oripa-port src/js/core/resource/GridType.js).
//
// Java `byte` enum-like constants -> Swift enum raw values.
public enum GridType: Int, CaseIterable, Sendable {
    case square = 0
    case triangle = 1
    case undefined = 127

    // 1:1 Java constant names.
    public static let SQUARE = GridType.square
    public static let TRIANGLE = GridType.triangle
    public static let UNDEFINED = GridType.undefined
}

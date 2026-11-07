// Port of `com.origamitoolbox.oripa.resource.RenderKey` (oripa-port src/js/core/resource/RenderKey.js).
//
// Raw string keys of the Android render-data buffers; `key(str)` builds the fully qualified
// key `com.origamitoolbox.oripa.RenderKey.<str>`.
public enum RenderKey {
    public static let BUNDLE_FOLD_OVERLAP = "BUNDLE_FOLD_OVERLAP"
    public static let BUNDLE_FOLD_OVERLAP_SPLIT = "BUNDLE_FOLD_OVERLAP_SPLIT_%d"
    public static let BUNDLE_FOLD_XRAY_CROSS = "BUNDLE_FOLD_XRAY_CROSS"
    public static let CP_LINE_DRAW_ORDER = "CP_LINE_DRAW_ORDER"
    public static let CP_LINE_POSITION = "CP_LINE_POSITION"
    public static let CP_LINE_TYPE = "CP_LINE_TYPE"
    public static let CP_POINT_POSITION = "CP_POINT_POSITION"
    public static let CP_POINT_POSITION_ERROR = "CP_POINT_POSITION_ERROR"
    public static let CP_POLYGON_DRAW_ORDER = "CP_POLYGON_DRAW_ORDER"
    public static let CP_POLYGON_POSITION = "CP_POLYGON_POSITION"
    public static let OVERLAP_ANGLE_DEG = "OVERLAP_ANGLE_DEG"
    public static let OVERLAP_ANGLE_DEG_REVERSE = "OVERLAP_ANGLE_DEG_REVERSE"
    public static let OVERLAP_DRAW_ORDER = "OVERLAP_DRAW_ORDER"
    public static let OVERLAP_DRAW_ORDER_REVERSE = "OVERLAP_DRAW_ORDER_REVERSE"
    public static let OVERLAP_POSITION = "OVERLAP_POSITION"
    public static let OVERLAP_POSITION_REVERSE = "OVERLAP_POSITION_REVERSE"
    public static let OVERLAP_TYPE = "OVERLAP_TYPE"
    public static let OVERLAP_TYPE_REVERSE = "OVERLAP_TYPE_REVERSE"
    public static let XRAY_FACE_DRAW_ORDER = "XRAY_FACE_DRAW_ORDER"
    public static let XRAY_LINE_BOUNDARY_DRAW_ORDER = "XRAY_LINE_BOUNDARY_DRAW_ORDER"
    public static let XRAY_LINE_CREASE_DRAW_ORDER = "XRAY_LINE_CREASE_DRAW_ORDER"
    public static let XRAY_POINT_POSITION = "XRAY_POINT_POSITION"

    /// `RenderKey.key(str)`.
    public static func key(_ str: String) -> String {
        "com.origamitoolbox.oripa.RenderKey." + str
    }
}

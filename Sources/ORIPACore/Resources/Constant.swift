// Port of `com.origamitoolbox.oripa.resource.Constant` (oripa-port src/js/core/resource/Constant.js).
import Foundation

/// All numeric app constants. Java `float` -> `Float`, Java `int` -> `Int`.
public enum Constant {
    public static let ALPHA_FOLD_CP_XRAY_FACE: Float = 0.05
    public static let ALPHA_FOLD_CP_XRAY_LINE_BOUNDARY: Float = 0.2
    public static let ALPHA_FOLD_CP_XRAY_LINE_CREASE: Float = 0.15
    public static let LINE_HALF_WIDTH_DEFAULT_DP: Float = 1.0
    public static let LINE_HALF_WIDTH_DEFAULT_PX: Float = 2.0
    public static let LINE_HALF_WIDTH_FOLD_CP_OVERLAP_DP: Float = 1.0
    public static let LINE_HALF_WIDTH_FOLD_CP_OVERLAP_PX: Float = 2.0
    public static let LINE_HALF_WIDTH_GRID_DP: Float = 0.5
    public static let LINE_HALF_WIDTH_MIRROR_DP: Float = 3.0
    public static let LINE_WIDTH_DEFAULT: Float = 3.0
    public static let LINE_WIDTH_FOLD_CP_BOUNDARY: Float = 10.0
    public static let LINE_WIDTH_FOLD_CP_CREASE: Float = 4.0
    public static let LINE_WIDTH_FOLD_CP_CROSS: Float = 6.0
    public static let LINE_WIDTH_FOLD_CP_CROSS_THICK: Float = 10.0
    public static let LINE_WIDTH_SCREEN_DIVIDER: Float = 10.0
    public static let MAX_SCALE_FACTOR: Float = 10000.0
    public static let MIN_SCALE_FACTOR: Float = 0.2
    public static let POINT_SIZE_DEFAULT: Float = 12.0
    public static let POINT_SIZE_EMPHASIS: Float = 24.0
    public static let SCREEN_TOUCH_RADIUS_DP: Float = 16.0
    public static let SELECTION_RECT_DASH_LENGTH_DP: Float = 10.0
    public static let SINGLE_GRID_IMAGE_DIMEN_DP: Int = 180
    public static let SINGLE_LIST_IMAGE_DIMEN_DP: Int = 32
    public static let TOUCH_CIRCLE_DURATION_MILLISECONDS: Int = 200
}

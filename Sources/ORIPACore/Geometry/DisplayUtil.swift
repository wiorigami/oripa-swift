// Port of `com.origamitoolbox.oripa.util.DisplayUtil` (oripa-port src/js/core/util/DisplayUtil.js).
//
// Android `Context`/`DisplayMetrics` are replaced by explicit parameters. The port renders in
// CSS points (dp), so density defaults to 1 (dp == px) unless a density is supplied.
import Foundation

public enum DisplayUtil {
    /// `getPixelFromDp(dp)` — identity in CSS px (density 1).
    public static func getPixelFromDp(_ dp: Double) -> Double {
        dp
    }

    /// `getPixelFromDp(density, dp)`.
    public static func getPixelFromDp(_ density: Double, _ dp: Double) -> Double {
        dp * density
    }

    public static func getPixelFromDp(_ dp: Float) -> Float {
        Float(getPixelFromDp(Double(dp)))
    }

    public static func getPixelFromDp(_ density: Float, _ dp: Float) -> Float {
        Float(getPixelFromDp(Double(density), Double(dp)))
    }

    /// `getGridColumnCount(widthPixels, itemDp)`.
    public static func getGridColumnCount(_ widthPixels: Double, _ itemDp: Double) -> Int {
        max(1, Int(JavaMath.round(widthPixels / itemDp)))
    }

    /// `getGridColumnCount(widthPixels, density, itemDp)`.
    public static func getGridColumnCount(_ widthPixels: Double, _ density: Double, _ itemDp: Double) -> Int {
        let widthDp = widthPixels / density
        return max(1, Int(JavaMath.round(widthDp / itemDp)))
    }

    public static func getGridColumnCount(_ widthPixels: Float, _ itemDp: Float) -> Int {
        getGridColumnCount(Double(widthPixels), Double(itemDp))
    }

    public static func getGridColumnCount(_ widthPixels: Float, _ density: Float, _ itemDp: Float) -> Int {
        getGridColumnCount(Double(widthPixels), Double(density), Double(itemDp))
    }
}

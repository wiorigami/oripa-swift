// Port of `com.origamitoolbox.oripa.util.ColorUtil` (oripa-port src/js/core/util/ColorUtil.js).
//
// Android `android.graphics.Color` HSV conversions reimplemented with the same Skia-style
// semantics as the JS reference. Colors are ARGB `Int`s.
import Foundation

public enum ColorUtil {
    private static let MASK24 = 0x00FF_FFFF

    private static func hex6(_ value: Int) -> String {
        var text = String(value & MASK24, radix: 16, uppercase: true)
        while text.count < 6 { text = "0" + text }
        return text
    }

    /// Skia/JS `rgbToHSV`: writes `[h, s, v]`.
    private static func rgbToHSV(_ color: Int) -> [Double] {
        let r = Double((color >> 16) & 0xFF) / 255.0
        let g = Double((color >> 8) & 0xFF) / 255.0
        let b = Double(color & 0xFF) / 255.0
        let maxValue = max(r, max(g, b))
        let minValue = min(r, min(g, b))
        let delta = maxValue - minValue
        var hsv = [0.0, 0.0, maxValue]
        if maxValue == 0.0 {
            hsv[0] = 0.0
            hsv[1] = 0.0
            return hsv
        }
        hsv[1] = delta / maxValue
        if delta == 0.0 {
            hsv[0] = 0.0
            return hsv
        }
        var h: Double
        if r == maxValue {
            h = (g - b) / delta
        } else if g == maxValue {
            h = 2.0 + ((b - r) / delta)
        } else {
            h = 4.0 + ((r - g) / delta)
        }
        h *= 60.0
        if h < 0.0 { h += 360.0 }
        hsv[0] = h
        return hsv
    }

    private static func hsvToColor(_ alpha: Int, _ hsv: [Double]) -> Int {
        precondition(hsv.count >= 3, "3 components required for hsv")
        var h = hsv[0]
        let s = hsv[1]
        let v = hsv[2]
        var r = 0.0
        var g = 0.0
        var b = 0.0
        if s == 0.0 {
            r = v
            g = v
            b = v
        } else {
            h = h.truncatingRemainder(dividingBy: 360.0)
            if h < 0.0 { h += 360.0 }
            let hf = h / 60.0
            let i = hf.rounded(.down)
            let f = hf - i
            let pv = v * (1.0 - s)
            let qv = v * (1.0 - (s * f))
            let tv = v * (1.0 - (s * (1.0 - f)))
            switch Int(i) % 6 {
            case 0: r = v; g = tv; b = pv
            case 1: r = qv; g = v; b = pv
            case 2: r = pv; g = v; b = tv
            case 3: r = pv; g = qv; b = v
            case 4: r = tv; g = pv; b = v
            default: r = v; g = pv; b = qv
            }
        }
        let ri = Int(((r * 255.0) + 0.5).rounded(.down))
        let gi = Int(((g * 255.0) + 0.5).rounded(.down))
        let bi = Int(((b * 255.0) + 0.5).rounded(.down))
        return Int(Int32(truncatingIfNeeded:
            ((alpha & 0xFF) << 24) | ((ri & 0xFF) << 16) | ((gi & 0xFF) << 8) | (bi & 0xFF)))
    }

    /// Java `getHueAngleDeg(int)`.
    public static func getHueAngleDeg(_ i: Int) -> Double {
        rgbToHSV(i)[0]
    }

    /// Java `getRainbow()`: `SupportMenu.CATEGORY_MASK, magenta, blue, cyan, green,
    /// InputDeviceCompat.SOURCE_ANY, red`.
    public static func getRainbow() -> [Int] {
        [Int(Int32(bitPattern: 0xFFFF_0000)),
         Int(Int32(bitPattern: 0xFFFF_00FF)),
         Int(Int32(bitPattern: 0xFF00_00FF)),
         Int(Int32(bitPattern: 0xFF00_FFFF)),
         Int(Int32(bitPattern: 0xFF00_FF00)),
         Int(Int32(bitPattern: 0xFFFF_FF00)),
         Int(Int32(bitPattern: 0xFFFF_0000))]
    }

    /// Java `getRgbFloatFromInt(int)`.
    public static func getRgbFloatFromInt(_ i: Int) -> [Float] {
        [Float((i >> 16) & 0xFF) / 255.0,
         Float((i >> 8) & 0xFF) / 255.0,
         Float(i & 0xFF) / 255.0]
    }

    /// Java `getSaturatedHue(float)`.
    public static func getSaturatedHue(_ f: Double) -> Int {
        hsvToColor(0xFF, [f, 1.0, 1.0])
    }

    /// Java `String.format("#%06X", i & MEASURED_SIZE_MASK)`.
    public static func intToStringRgb(_ i: Int) -> String {
        "#" + hex6(i & MASK24)
    }

    public static func intToStringRgbNoHash(_ i: Int) -> String {
        hex6(i & MASK24)
    }
}

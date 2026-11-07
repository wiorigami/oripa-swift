// Port of `com.origamitoolbox.oripa.resource.Color` (see oripa-port src/js/core/resource/Color.js).
//
// Android stores each color as `float[3]` in RGB order (0...1). The Swift port exposes
// those arrays as `RGB` values; renderers can use `.r/.g/.b` or `.components`.
import Foundation

/// A three-component RGB color with Android's `float` precision.
public struct RGB: Equatable, Hashable, Sendable, CustomStringConvertible {
    public var r: Float
    public var g: Float
    public var b: Float

    public init(_ r: Float, _ g: Float, _ b: Float) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Android `float[3] {r, g, b}` -> RGB.
    public init(_ components: [Float]) {
        self.r = components.count > 0 ? components[0] : 0
        self.g = components.count > 1 ? components[1] : 0
        self.b = components.count > 2 ? components[2] : 0
    }

    /// RGB -> Android `float[3]`.
    public var components: [Float] { [r, g, b] }

    public var description: String { "RGB(\(r), \(g), \(b))" }
}

/// Port of the Android `Color` resource holder (raw RGB constants, not `UIColor`).
public enum Color {
    public static let COLOR_BOUNDARY = RGB(0.0, 0.0, 0.0)
    public static let COLOR_VALLEY = RGB(0.0, 0.0, 1.0)
    public static let COLOR_MOUNTAIN = RGB(1.0, 0.0, 0.0)
    public static let COLOR_FLAT = RGB(0.0, 1.0, 1.0)
    public static let COLOR_GRID = RGB(0.5, 0.5, 0.5)
    public static let COLOR_SLICE = RGB(1.0, 0.0, 1.0)
    public static let COLOR_PICKED = RGB(0.0, 1.0, 0.0)
    public static let COLOR_ERROR = RGB(1.0, 0.0, 0.0)
    public static let COLOR_CP_POLYGON_FILL = RGB(1.0, 0.824, 0.824)
    public static let COLOR_TOUCH_CIRCLE = RGB(0.913, 0.117, 0.388)
    public static let COLOR_SELECTION_RECT = RGB(0.913, 0.117, 0.388)
    public static let COLOR_XRAY_FACE = RGB(0.0, 0.0, 0.0)
    public static let COLOR_XRAY_CREASE = RGB(0.0, 0.0, 0.0)
    public static let COLOR_XRAY_BOUNDARY = RGB(0.0, 0.0, 0.0)
    public static let COLOR_WIRE_CREASE = RGB(0.5, 0.5, 0.5)
    public static let COLOR_WIRE_BOUNDARY = RGB(0.0, 0.0, 0.0)
}

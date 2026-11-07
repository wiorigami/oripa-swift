// Port of `com.origamitoolbox.oripa.resource.LineType` (oripa-port src/js/core/resource/LineType.js).
//
// Java `byte` line-type constants keep their exact values. Helper tables mirror the Java
// static arrays: `colors` (index 0...7, 7 -> null), `strings` and `abbreviations`
// (`BuildConfig.FLAVOR` == "" for the release APK).
import Foundation

public enum LineType: Int, CaseIterable, Sendable {
    case flat = 0
    case boundary = 1
    case mountain = 2
    case valley = 3
    case grid = 4
    case picked = 5
    case slice = 6
    case undefined = 127

    // 1:1 Java constant names (handy when reading the Java/JS reference next to the Swift).
    public static let FLAT = LineType.flat
    public static let BOUNDARY = LineType.boundary
    public static let MOUNTAIN = LineType.mountain
    public static let VALLEY = LineType.valley
    public static let GRID = LineType.grid
    public static let PICKED = LineType.picked
    public static let SLICE = LineType.slice
    public static let UNDEFINED = LineType.undefined

    /// Java `colors` array; `nil` at index 7 like the Java `null` entry.
    private static let COLOR_NAMES: [String?] = [
        "COLOR_FLAT", "COLOR_BOUNDARY", "COLOR_MOUNTAIN", "COLOR_VALLEY",
        "COLOR_GRID", "COLOR_PICKED", "COLOR_SLICE", nil,
    ]
    private static let STRINGS = ["FLAT", "BOUNDARY", "MOUNTAIN", "VALLEY", "GRID", "PICKED", "SLICE", "UNDEFINED"]
    private static let ABBREVIATIONS = ["fl", "bo", "mo", "va", "gr", "pi", "sl", ""]

    // MARK: - Java static helpers (byte argument)

    /// `LineType.getAbbreviation(byte)`: out-of-range indexes are absent in Java's array
    /// (the JS returns `undefined`), so this returns `nil`.
    public static func getAbbreviation(_ b: Int) -> String? {
        guard b >= 0 && b < ABBREVIATIONS.count else { return nil }
        return ABBREVIATIONS[b]
    }

    /// `LineType.getColor(byte)`: `nil` for the Java `null` entry and out-of-range values.
    public static func getColor(_ b: Int) -> RGB? {
        guard b >= 0 && b < COLOR_NAMES.count, let name = COLOR_NAMES[b] else { return nil }
        return color(named: name)
    }

    /// `LineType.getString(byte)`.
    public static func getString(_ b: Int) -> String? {
        guard b >= 0 && b < STRINGS.count else { return nil }
        return STRINGS[b]
    }

    private static func color(named name: String) -> RGB? {
        switch name {
        case "COLOR_FLAT": return Color.COLOR_FLAT
        case "COLOR_BOUNDARY": return Color.COLOR_BOUNDARY
        case "COLOR_MOUNTAIN": return Color.COLOR_MOUNTAIN
        case "COLOR_VALLEY": return Color.COLOR_VALLEY
        case "COLOR_GRID": return Color.COLOR_GRID
        case "COLOR_PICKED": return Color.COLOR_PICKED
        case "COLOR_SLICE": return Color.COLOR_SLICE
        default: return nil
        }
    }

    // MARK: - Convenience accessors on the typed value

    /// Color used to draw this line type; `nil` for `.undefined`.
    public func getColor() -> RGB? { LineType.getColor(rawValue) }

    /// Uppercase name, e.g. `"MOUNTAIN"`.
    public func getString() -> String { LineType.getString(rawValue) ?? "UNDEFINED" }

    /// Two-letter drawing abbreviation, e.g. `"va"`.
    public func getAbbreviation() -> String { LineType.getAbbreviation(rawValue) ?? "" }

    public var string: String { getString() }
    public var abbreviation: String { getAbbreviation() }
}

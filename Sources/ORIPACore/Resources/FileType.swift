// Port of `com.origamitoolbox.oripa.resource.FileType` (oripa-port src/js/core/resource/FileType.js).
//
// Java enum FileType { PNG, SVG, OPX, OPXC, CP } with getExtension()/getMimeType().
// `getMimeType` consults the IO-layer `FileUtil` on Android; ORIPACore stays Foundation-only,
// so the same fallback table the JS port uses (PNG/SVG from MimeTypeMap, OPX/OPXC -> text/xml,
// default text/plain) is inlined here.
import Foundation

public enum FileType: Int, CaseIterable, Sendable {
    case png = 0
    case svg = 1
    case opx = 2
    case opxc = 3
    case cp = 4

    // 1:1 Java constant names.
    public static let PNG = FileType.png
    public static let SVG = FileType.svg
    public static let OPX = FileType.opx
    public static let OPXC = FileType.opxc
    public static let CP = FileType.cp

    private static let MIME_TYPES: [String: String] = [
        "png": "image/png",
        "svg": "image/svg+xml",
    ]

    /// Java `name()`.
    public var name: String {
        switch self {
        case .png: return "PNG"
        case .svg: return "SVG"
        case .opx: return "OPX"
        case .opxc: return "OPXC"
        case .cp: return "CP"
        }
    }

    /// Java `ordinal()`.
    public var ordinal: Int { rawValue }

    /// Java `getExtension()` — lowercased enum name.
    public func getExtension() -> String { name.lowercased() }

    /// Swift-friendly alias for `getExtension()`.
    public var fileExtension: String { getExtension() }

    /// Swift-friendly alias for Swift code that cannot spell `extension` as a bare label.
    public var ext: String { getExtension() }

    /// Java `getMimeType()`.
    public func getMimeType() -> String {
        let fileExtension = getExtension()
        if let mime = FileType.MIME_TYPES[fileExtension] { return mime }
        switch self {
        case .opx, .opxc: return "text/xml"
        default: return "text/plain"
        }
    }

    public var mimeType: String { getMimeType() }

    /// Display name used by export menus/dialogs (Java `toString()`).
    public var displayName: String { name }

    public func toString() -> String { name }

    /// Java `values()`.
    public static func values() -> [FileType] { allCases }

    /// Java `valueOf(String)`; JS throws `No enum constant FileType.<name>`.
    public static func valueOf(_ name: String) -> FileType? {
        allCases.first { $0.name == name }
    }
}

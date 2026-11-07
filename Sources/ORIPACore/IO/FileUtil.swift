// Port of `src/js/core/io/FileUtil.js` (Java `com.origamitoolbox.oripa.io.FileUtil` with all
// Android storage/Context APIs removed). Name/extension/mime/timestamp helpers only; the
// actual filesystem lives in the UI/platform layer (ProjectStore / FileExchange).
import Foundation

public enum FileUtil {
    /// Java: substring after the last "." lower-cased; the whole string (no dot) -> "".
    public static func getFileExt(_ str: String) -> String {
        let text = String(str)
        guard let dot = text.lastIndex(of: ".") else { return "" }
        let lowerCase = String(text[text.index(after: dot)...]).lowercased()
        return lowerCase == text ? "" : lowerCase
    }

    public static func getFilenameNoExt(_ str: String) -> String {
        let text = String(str)
        guard let dot = text.lastIndex(of: ".") else { return text }
        return String(text[..<dot])
    }

    public static func getFilenameWithExt(_ fileType: FileType, _ str: String) -> String {
        str + "." + fileType.getExtension()
    }

    /// Android MimeTypeMap replacement (only the formats ORIPA knows).
    private static let MIME_TYPES: [String: String] = [
        "png": "image/png",
        "svg": "image/svg+xml",
        "opx": "text/xml",
        "opxc": "text/xml",
        "cp": "text/plain",
    ]

    public static func getMimeType(_ str: String) -> String? {
        MIME_TYPES[String(str).lowercased()]
    }

    /// Java `DateFormat.getDateTimeInstance().format(new Date(mtime))`.
    /// `mtime` is milliseconds since the epoch (platform.fs entries carry it).
    public static func getLastModifiedText(_ mtime: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: Date(timeIntervalSince1970: mtime / 1000.0))
    }

    /// Java `DateFormat.getDateTimeInstance(DateFormat.SHORT, DateFormat.SHORT)`.
    public static func getLastModifiedTextShort(_ mtime: Double) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: mtime / 1000.0))
    }
}

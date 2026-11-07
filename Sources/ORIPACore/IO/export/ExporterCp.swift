// Port of `src/js/core/io/export/ExporterCp.js` (Java
// `com.origamitoolbox.oripa.io.export.ExporterCp`).
//
// Serializes a CreasePattern to the `.cp` text format: one "type x0 y0 x1 y1" line per
// mountain/valley/flat/boundary line; flat (type 0) lines are skipped.
// Returns UTF-8 bytes (Java byte[]); System line.separator == "\n" on Android.
import Foundation

public enum ExporterCp {
    public static func getCreasePattern(_ creasePattern: CreasePattern) -> Data {
        var out = ""
        for line in creasePattern.lineMVFB {
            let type = line.type().rawValue
            if type != 0 {
                out += String(type) + " " +
                    OripaIO.doubleToString(line.start.x) + " " +
                    OripaIO.doubleToString(line.start.y) + " " +
                    OripaIO.doubleToString(line.end.x) + " " +
                    OripaIO.doubleToString(line.end.y) + "\n"
            }
        }
        return OripaIO.textToBytes(out)
    }
}

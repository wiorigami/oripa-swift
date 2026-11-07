// Port of `src/js/core/io/export/ExporterOpxc.js` (Java
// `com.origamitoolbox.oripa.io.export.ExporterOpxc`).
//
//   <data version="1.0" paperSize="400.0">
//     <line type="2" x1=".." y1=".." x2=".." y2=".."/>
//   </data>
//
// Zero coordinates and type 0 are omitted (the loader defaults them to 0).
import Foundation

public enum ExporterOpxc {
    private static let TAG_LINE = "line"
    private static let TAG_ROOT = "data"
    private static let ATTRIBUTE_OPXC_VERSION = "1.0"  // Java Double.toString(1.0)

    public static func getCreasePattern(_ creasePattern: CreasePattern) -> Data {
        var out = ""
        out += "<?xml version='1.0' encoding='UTF-8'?>\n"
        out += "<" + TAG_ROOT + " version=\"" + ATTRIBUTE_OPXC_VERSION + "\" paperSize=\"" +
            OripaIO.doubleToString(Double(creasePattern.creasePatternHalfSize) * 2.0) + "\">\n"
        for line in creasePattern.lineMVFB {
            out += "<" + TAG_LINE
            let type = line.type().rawValue
            if type != 0 { out += " type=\"\(type)\"" }
            if OriPoint.getKey(line.start.x) != 0 { out += " x1=\"\(OripaIO.doubleToString(line.start.x))\"" }
            if OriPoint.getKey(line.start.y) != 0 { out += " y1=\"\(OripaIO.doubleToString(line.start.y))\"" }
            if OriPoint.getKey(line.end.x) != 0 { out += " x2=\"\(OripaIO.doubleToString(line.end.x))\"" }
            if OriPoint.getKey(line.end.y) != 0 { out += " y2=\"\(OripaIO.doubleToString(line.end.y))\"" }
            out += "/>\n"
        }
        out += "</" + TAG_ROOT + ">\n"
        return OripaIO.textToBytes(out)
    }
}

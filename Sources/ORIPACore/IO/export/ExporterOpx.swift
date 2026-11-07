// Port of `src/js/core/io/export/ExporterOpx.js` (Java
// `com.origamitoolbox.oripa.io.export.ExporterOpx`).
//
// Serializes a CreasePattern to the legacy `.opx` format: the same java.beans.XMLDecoder
// document Android's XmlSerializer produced (oripa.DataSet with an array of
// oripa.OriLineProxy). Indentation differs from Android's serializer but the document
// structure and every attribute/element are the same.
import Foundation

public enum ExporterOpx {
    private static let VERSION = "1.8.0_91"

    public static func getCreasePattern(_ creasePattern: CreasePattern) -> Data {
        var out = ""
        out += "<?xml version='1.0' encoding='UTF-8'?>\n"
        out += "<java version=\"1.8.0_91\" class=\"java.beans.XMLDecoder\">\n"
        out += " <object class=\"oripa.DataSet\" id=\"DataSet0\">\n"
        out += "  <void class=\"oripa.DataSet\" method=\"getField\">\n"
        out += "   <string>lines</string>\n"
        out += "   <void method=\"set\">\n"
        out += "    <object idref=\"DataSet0\"/>\n"
        out += "    <array class=\"oripa.OriLineProxy\" length=\"\(creasePattern.lineMVFB.size())\">\n"
        var index = 0
        for line in creasePattern.lineMVFB {
            out += "     <void index=\"\(index)\">\n"
            out += "      <object class=\"oripa.OriLineProxy\">\n"
            let type = line.type().rawValue
            if type != 0 {
                out += "       <void property=\"type\">\n"
                out += "        <int>\(type)</int>\n"
                out += "       </void>\n"
            }
            if OriPoint.getKey(line.start.x) != 0 {
                out += "       <void property=\"x0\">\n"
                out += "        <double>\(OripaIO.doubleToString(line.start.x))</double>\n"
                out += "       </void>\n"
            }
            if OriPoint.getKey(line.end.x) != 0 {
                out += "       <void property=\"x1\">\n"
                out += "        <double>\(OripaIO.doubleToString(line.end.x))</double>\n"
                out += "       </void>\n"
            }
            if OriPoint.getKey(line.start.y) != 0 {
                out += "       <void property=\"y0\">\n"
                out += "        <double>\(OripaIO.doubleToString(line.start.y))</double>\n"
                out += "       </void>\n"
            }
            if OriPoint.getKey(line.end.y) != 0 {
                out += "       <void property=\"y1\">\n"
                out += "        <double>\(OripaIO.doubleToString(line.end.y))</double>\n"
                out += "       </void>\n"
            }
            out += "      </object>\n"
            out += "     </void>\n"
            index += 1
        }
        out += "    </array>\n"
        out += "   </void>\n"
        out += "  </void>\n"
        out += "  <void property=\"mainVersion\">\n"
        out += "   <int>1</int>\n"
        out += "  </void>\n"
        out += "  <void property=\"paperSize\">\n"
        out += "   <double>\(OripaIO.doubleToString(Double(creasePattern.creasePatternHalfSize) * 2.0))</double>\n"
        out += "  </void>\n"
        out += "  <void property=\"subVersion\">\n"
        out += "   <int>1</int>\n"
        out += "  </void>\n"
        out += " </object>\n"
        out += "</java>\n"
        return OripaIO.textToBytes(out)
    }
}

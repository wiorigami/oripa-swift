// Port of `src/js/core/io/load/LoaderOpxc.js` (Java
// `com.origamitoolbox.oripa.io.load.LoaderOpxc`).
//
// `.opxc` = plain XML (NOT compressed; verified against jadx + smali):
//
//   <data version="1.0" paperSize="400.0">
//     <line type="2" x1=".." y1=".." x2=".." y2=".."/>
//   </data>
//
// Attributes equal to 0 are omitted by the exporter; missing attributes/type default to 0,
// as in the Java loader. `version`/`paperSize` are ignored (CP half size keeps its default).
import Foundation

public enum LoaderOpxc {
    private static let ATTRIBUTE_TYPE = "type"
    private static let ATTRIBUTE_X1 = "x1"
    private static let ATTRIBUTE_X2 = "x2"
    private static let ATTRIBUTE_Y1 = "y1"
    private static let ATTRIBUTE_Y2 = "y2"
    private static let TAG_LINE = "line"
    private static let TAG_ROOT = "data"
    private static let NAMESPACE: String? = nil

    public static func getCreasePattern(
        _ filenameWithExt: String,
        _ data: Data,
        _ creasePattern: CreasePattern
    ) throws {
        try getCreasePattern(filenameWithExt, OripaIO.bytesToText(data), creasePattern)
    }

    public static func getCreasePattern(
        _ filenameWithExt: String,
        _ text: String,
        _ creasePattern: CreasePattern
    ) throws {
        let parser = XmlPullParser()
        parser.setFeature("http://xmlpull.org/v1/doc/features.html#process-namespaces", false)
        parser.setInput(text)
        try parser.nextTag()
        try readCreasePattern(parser, creasePattern)
    }

    private static func readCpLine(_ parser: XmlPullParser, _ creasePattern: CreasePattern) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_LINE)
        let x1 = parser.getAttributeValue(nil, ATTRIBUTE_X1)
        let y1 = parser.getAttributeValue(nil, ATTRIBUTE_Y1)
        let x2 = parser.getAttributeValue(nil, ATTRIBUTE_X2)
        let y2 = parser.getAttributeValue(nil, ATTRIBUTE_Y2)
        let type = parser.getAttributeValue(nil, ATTRIBUTE_TYPE)
        let start = OriPoint(
            try x1.map { try JavaNumberFormat.parseDouble($0) } ?? 0.0,
            try y1.map { try JavaNumberFormat.parseDouble($0) } ?? 0.0)
        let end = OriPoint(
            try x2.map { try JavaNumberFormat.parseDouble($0) } ?? 0.0,
            try y2.map { try JavaNumberFormat.parseDouble($0) } ?? 0.0)
        let lineType = try type.map { try JavaNumberFormat.parseByte($0) } ?? 0
        creasePattern.addLineCheckNoException(
            OriLine(start, end, LineType(rawValue: lineType) ?? .undefined))
        try parser.nextTag()
        try parser.require(XmlPullParser.END_TAG, NAMESPACE, TAG_LINE)
    }

    private static func readCreasePattern(_ parser: XmlPullParser, _ creasePattern: CreasePattern) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_ROOT)
        while try parser.next() != XmlPullParser.END_TAG {
            if parser.getEventType() == XmlPullParser.START_TAG && parser.getName() == TAG_LINE {
                try readCpLine(parser, creasePattern)
            }
        }
    }
}

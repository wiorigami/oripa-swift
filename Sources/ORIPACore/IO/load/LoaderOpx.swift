// Port of `src/js/core/io/load/LoaderOpx.js` (Java
// `com.origamitoolbox.oripa.io.load.LoaderOpx`).
//
// Legacy `.opx` format: a `java.beans.XMLDecoder` document containing an `oripa.DataSet`
// with an array of `oripa.OriLineProxy` objects. android.util.Xml / XmlPullParser is
// replaced by ORIPACore's `XmlPullParser` so the same event walk runs everywhere.
import Foundation

public enum LoaderOpx {
    private static let TAG_ARRAY = "array"
    private static let TAG_OBJECT = "object"
    private static let TAG_VOID = "void"
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
        var eventType = parser.getEventType()
        while eventType != XmlPullParser.END_DOCUMENT {
            if eventType == XmlPullParser.START_TAG && parser.getName() == TAG_ARRAY {
                try readCPArray(parser, creasePattern)
                return
            }
            eventType = try parser.next()
        }
    }

    private static func readText(_ parser: XmlPullParser) throws -> String {
        if try parser.next() != XmlPullParser.TEXT { return "" }  // BuildConfig.FLAVOR == ""
        let text = parser.getText() ?? ""
        try parser.nextTag()
        return text
    }

    private static func readTextInner(_ parser: XmlPullParser, _ tagName: String) throws -> String {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, tagName)
        let text = try readText(parser)
        try parser.require(XmlPullParser.END_TAG, NAMESPACE, tagName)
        return text
    }

    private static func readByte(_ parser: XmlPullParser) throws -> Int {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_VOID)
        try parser.nextTag()
        let value = try JavaNumberFormat.parseByte(readTextInner(parser, "int"))
        try parser.nextTag()
        try parser.require(XmlPullParser.END_TAG, NAMESPACE, TAG_VOID)
        return value
    }

    private static func readDouble(_ parser: XmlPullParser) throws -> Double {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_VOID)
        try parser.nextTag()
        let value = try JavaNumberFormat.parseDouble(readTextInner(parser, "double"))
        try parser.nextTag()
        try parser.require(XmlPullParser.END_TAG, NAMESPACE, TAG_VOID)
        return value
    }

    private static func readOriLine(_ parser: XmlPullParser, _ creasePattern: CreasePattern) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_OBJECT)
        if parser.getAttributeValue(nil, "class") != "oripa.OriLineProxy" { return }
        var x0 = Double.nan
        var y0 = Double.nan
        var x1 = Double.nan
        var y1 = Double.nan
        var type = -1
        while true {
            if try parser.next() == XmlPullParser.END_TAG {
                let lineType = type != -1 ? type : 0
                if x0.isNaN { x0 = 0.0 }
                if y0.isNaN { y0 = 0.0 }
                if x1.isNaN { x1 = 0.0 }
                if y1.isNaN { y1 = 0.0 }
                let line = OriLine(
                    OriPoint(x0, y0),
                    OriPoint(x1, y1),
                    LineType(rawValue: lineType) ?? .undefined)
                creasePattern.addLineCheckNoException(line)
                try parser.require(XmlPullParser.END_TAG, NAMESPACE, TAG_OBJECT)
                return
            }
            if parser.getEventType() == XmlPullParser.START_TAG {
                switch parser.getAttributeValue(nil, "property") {
                case "type": type = try readByte(parser)
                case "x0": x0 = try readDouble(parser)
                case "y0": y0 = try readDouble(parser)
                case "x1": x1 = try readDouble(parser)
                case "y1": y1 = try readDouble(parser)
                default: break
                }
            }
        }
    }

    private static func readCPArray(_ parser: XmlPullParser, _ creasePattern: CreasePattern) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_ARRAY)
        while try parser.next() != XmlPullParser.END_TAG {
            if parser.getEventType() == XmlPullParser.START_TAG && parser.getName() == TAG_VOID &&
                parser.getAttributeValue(nil, "index") != nil {
                try parser.nextTag()
                try readOriLine(parser, creasePattern)
                try parser.nextTag()
            }
        }
    }
}

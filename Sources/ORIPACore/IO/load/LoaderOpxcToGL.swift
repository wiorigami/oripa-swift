// Port of `src/js/core/io/load/LoaderOpxcToGL.js` (Java
// `com.origamitoolbox.oripa.io.load.LoaderOpxcToGL`).
//
// Fast loader that turns an `.opxc` document directly into flat float/byte arrays for the
// preview renderer. Outputs / minmax are mutated like the Java method:
//   list  : [x1, y1, x2, y2, ...] per line
//   list2 : [type, type, ...] (two entries per line, as the Java)
//   minMax: MinMaxFloat (fallback viewport [-1,-1,1,1] for an empty file)
import Foundation

public enum LoaderOpxcToGL {
    private static let ATTRIBUTE_TYPE = "type"
    private static let ATTRIBUTE_X1 = "x1"
    private static let ATTRIBUTE_X2 = "x2"
    private static let ATTRIBUTE_Y1 = "y1"
    private static let ATTRIBUTE_Y2 = "y2"
    private static let TAG_LINE = "line"
    private static let TAG_ROOT = "data"
    private static let NAMESPACE: String? = nil

    public static func getCreasePattern(
        _ data: Data,
        _ list: inout [Float],
        _ list2: inout [Int],
        _ minMaxFloat: MinMaxFloat
    ) throws {
        try getCreasePattern(OripaIO.bytesToText(data), &list, &list2, minMaxFloat)
    }

    public static func getCreasePattern(
        _ text: String,
        _ list: inout [Float],
        _ list2: inout [Int],
        _ minMaxFloat: MinMaxFloat
    ) throws {
        let parser = XmlPullParser()
        parser.setFeature("http://xmlpull.org/v1/doc/features.html#process-namespaces", false)
        parser.setInput(text)
        try parser.nextTag()
        try readCreasePattern(parser, &list, &list2, minMaxFloat)
        if list.isEmpty {
            minMaxFloat.minX = -1.0
            minMaxFloat.minY = -1.0
            minMaxFloat.maxX = 1.0
            minMaxFloat.maxY = 1.0
        }
    }

    private static func readCpLine(
        _ parser: XmlPullParser,
        _ list: inout [Float],
        _ list2: inout [Int],
        _ minMaxFloat: MinMaxFloat
    ) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_LINE)
        let typeText = parser.getAttributeValue(nil, ATTRIBUTE_TYPE)
        let x1Text = parser.getAttributeValue(nil, ATTRIBUTE_X1)
        let y1Text = parser.getAttributeValue(nil, ATTRIBUTE_Y1)
        let x2Text = parser.getAttributeValue(nil, ATTRIBUTE_X2)
        let y2Text = parser.getAttributeValue(nil, ATTRIBUTE_Y2)
        // lenient parseFloat/parseInt like the JS built-ins
        let x1 = x1Text.map { JavaNumberFormat.parseFloatLenient($0) } ?? 0.0
        let y1 = y1Text.map { JavaNumberFormat.parseFloatLenient($0) } ?? 0.0
        let x2 = x2Text.map { JavaNumberFormat.parseFloatLenient($0) } ?? 0.0
        let y2 = y2Text.map { JavaNumberFormat.parseFloatLenient($0) } ?? 0.0
        list.append(Float(x1))
        list.append(Float(y1))
        list.append(Float(x2))
        list.append(Float(y2))
        let type = typeText.map { JavaNumberFormat.parseIntLenient($0) } ?? 0
        list2.append(type)
        list2.append(type)
        minMaxFloat.minX = Float(JavaNumberFormat.jsMin(Double(minMaxFloat.minX), x1))
        minMaxFloat.minX = Float(JavaNumberFormat.jsMin(Double(minMaxFloat.minX), x2))
        minMaxFloat.minY = Float(JavaNumberFormat.jsMin(Double(minMaxFloat.minY), y1))
        minMaxFloat.minY = Float(JavaNumberFormat.jsMin(Double(minMaxFloat.minY), y2))
        minMaxFloat.maxX = Float(JavaNumberFormat.jsMax(Double(minMaxFloat.maxX), x1))
        minMaxFloat.maxX = Float(JavaNumberFormat.jsMax(Double(minMaxFloat.maxX), x2))
        minMaxFloat.maxY = Float(JavaNumberFormat.jsMax(Double(minMaxFloat.maxY), y1))
        minMaxFloat.maxY = Float(JavaNumberFormat.jsMax(Double(minMaxFloat.maxY), y2))
        try parser.nextTag()
        try parser.require(XmlPullParser.END_TAG, NAMESPACE, TAG_LINE)
    }

    private static func skip(_ parser: XmlPullParser) throws {
        if parser.getEventType() != XmlPullParser.START_TAG { throw OripaIOError.runtime("IllegalStateException") }
        var depth = 1
        while depth != 0 {
            switch try parser.next() {
            case XmlPullParser.START_TAG: depth += 1
            case XmlPullParser.END_TAG: depth -= 1
            default: break
            }
        }
    }

    private static func readCreasePattern(
        _ parser: XmlPullParser,
        _ list: inout [Float],
        _ list2: inout [Int],
        _ minMaxFloat: MinMaxFloat
    ) throws {
        try parser.require(XmlPullParser.START_TAG, NAMESPACE, TAG_ROOT)
        while try parser.next() != XmlPullParser.END_TAG {
            if parser.getEventType() == XmlPullParser.START_TAG {
                if parser.getName() == TAG_LINE {
                    try readCpLine(parser, &list, &list2, minMaxFloat)
                } else {
                    try skip(parser)
                }
            }
        }
    }
}

// Port of `src/js/core/io/XmlPullParser.js` (dependency-free pull parser replacing
// Android's `org.xmlpull.v1.XmlPullParser`; same event sequence and `require()` checks).
//
// Events: START_DOCUMENT 0, END_DOCUMENT 1, START_TAG 2, END_TAG 3, TEXT 4.
// Comments, processing instructions and DOCTYPE are skipped (not used by the loaders).
// Entities in text/attribute values are decoded.
//
// Implementation note: the reference parses a JavaScript (UTF-16) string by index. The port
// works on UTF-16 code units so positions/`slice` semantics stay 1:1; ORIPA's XML files are
// ASCII in practice.
import Foundation

/// `XmlPullParserException` — same message shape as the JS port.
public struct XmlPullParserException: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { "XmlPullParserException: " + message }
}

public final class XmlPullParser {
    public static let START_DOCUMENT = 0
    public static let END_DOCUMENT = 1
    public static let START_TAG = 2
    public static let END_TAG = 3
    public static let TEXT = 4

    private var units: [UInt16] = []
    private var pos = 0
    private var eventType = START_DOCUMENT
    private var name: String?
    private var textValue: String?
    private var attributes: [String: String]?
    private var pendingEndTag: String?
    private var endEmitted = false

    public init() {}

    // MARK: - input

    public func setInput(_ text: String) {
        var units = Array(text.utf16)
        // strip UTF-8 BOM
        if units.first == 0xFEFF { units.removeFirst() }
        self.units = units
        pos = 0
        eventType = XmlPullParser.START_DOCUMENT
        name = nil
        textValue = nil
        attributes = nil
        pendingEndTag = nil
        endEmitted = false
    }

    /// Android pulls these features; the port is always namespace-unaware.
    public func setFeature(_ feature: String, _ value: Bool) {}

    // MARK: - current event

    public func getEventType() -> Int { eventType }

    public func getName() -> String? { name }

    public func getText() -> String? { textValue }

    public func getAttributeValue(_ namespace: String?, _ attributeName: String) -> String? {
        attributes?[attributeName]
    }

    public func getAttributeCount() -> Int { attributes?.count ?? 0 }

    // MARK: - character helpers

    private func charAt(_ index: Int) -> UInt16 {
        index >= 0 && index < units.count ? units[index] : 0
    }

    private func isWhitespace(_ c: UInt16) -> Bool {
        c == 0x20 || c == 0x09 || c == 0x0D || c == 0x0A
    }

    private func substring(_ start: Int, _ end: Int) -> String {
        let lo = max(0, min(start, units.count))
        let hi = max(lo, min(end, units.count))
        return String(decoding: units[lo..<hi], as: UTF16.self)
    }

    private func startsWith(_ token: String, at index: Int) -> Bool {
        let tokenUnits = Array(token.utf16)
        guard index >= 0, index + tokenUnits.count <= units.count else { return false }
        for (offset, unit) in tokenUnits.enumerated() where units[index + offset] != unit {
            return false
        }
        return true
    }

    private func indexOf(_ token: String, from start: Int) -> Int {
        let tokenUnits = Array(token.utf16)
        guard !tokenUnits.isEmpty else { return start }
        var i = max(0, start)
        while i + tokenUnits.count <= units.count {
            if startsWith(token, at: i) { return i }
            i += 1
        }
        return -1
    }

    private func skipPast(_ token: String) {
        let index = indexOf(token, from: pos)
        pos = index < 0 ? units.count : index + token.utf16.count
    }

    // MARK: - entity decoding

    /// JS `decodeEntities`: `&(#x?[0-9a-fA-F]+|[a-zA-Z]+);`.
    static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = ""
        result.reserveCapacity(string.count)
        var index = string.startIndex
        while index < string.endIndex {
            let character = string[index]
            if character != "&" {
                result.append(character)
                index = string.index(after: index)
                continue
            }
            // find the next ';' and try to decode the body
            guard let semicolon = string[index...].firstIndex(of: ";") else {
                result.append(character)
                index = string.index(after: index)
                continue
            }
            let bodyStart = string.index(after: index)
            let body = String(string[bodyStart..<semicolon])
            if let decoded = XmlPullParser.decodeEntityBody(body) {
                result += decoded
                index = string.index(after: semicolon)
            } else {
                result.append(character)
                index = string.index(after: index)
            }
        }
        return result
    }

    private static func decodeEntityBody(_ body: String) -> String? {
        guard !body.isEmpty else { return nil }
        if body.hasPrefix("#") {
            let digits = String(body.dropFirst())
            guard !digits.isEmpty else { return nil }
            let isHex = digits.hasPrefix("x") || digits.hasPrefix("X")
            let valueText = isHex ? String(digits.dropFirst()) : digits
            guard !valueText.isEmpty else { return nil }
            let valid: (Character) -> Bool = isHex
                ? { $0.isHexDigit }
                : { $0.isASCII && $0.isNumber }
            guard valueText.allSatisfy(valid), let code = UInt32(valueText, radix: isHex ? 16 : 10) else {
                return nil
            }
            guard let scalar = Unicode.Scalar(code) else { return nil }
            return String(Character(scalar))
        }
        guard body.allSatisfy({ ($0.isASCII && $0.isLetter) }) else { return nil }
        switch body {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        default: return nil
        }
    }

    // MARK: - parser

    private func parseStartTag() -> Int {
        // units[pos] == "<"
        pos += 1
        let start = pos
        while pos < units.count {
            let c = units[pos]
            if c == 0x3E || c == 0x2F || isWhitespace(c) { break }  // > / whitespace
            pos += 1
        }
        let tagName = substring(start, pos)
        var attrs: [String: String] = [:]
        var selfClosing = false
        while pos < units.count {
            let c = units[pos]
            if c == 0x3E {  // ">"
                pos += 1
                break
            }
            if c == 0x2F {  // "/"
                selfClosing = true
                pos += 1
                continue
            }
            if isWhitespace(c) {
                pos += 1
                continue
            }
            // attribute name
            let nameStart = pos
            while pos < units.count {
                let nc = units[pos]
                if nc == 0x3D || nc == 0x3E || nc == 0x2F || isWhitespace(nc) { break }  // = > /
                pos += 1
            }
            let attributeName = substring(nameStart, pos)
            while pos < units.count && isWhitespace(units[pos]) { pos += 1 }
            if charAt(pos) != 0x3D {  // "="
                // attribute without value (not used by ORIPA files)
                if !attributeName.isEmpty { attrs[attributeName] = "" }
                continue
            }
            pos += 1  // "="
            while pos < units.count && isWhitespace(units[pos]) { pos += 1 }
            let quote = charAt(pos)
            if quote != 0x22 && quote != 0x27 { break }  // " or '
            pos += 1
            let valueStart = pos
            var valueEnd = -1
            var scan = pos
            while scan < units.count {
                if units[scan] == quote {
                    valueEnd = scan
                    break
                }
                scan += 1
            }
            if valueEnd < 0 { valueEnd = units.count }
            attrs[attributeName] = XmlPullParser.decodeEntities(substring(valueStart, valueEnd))
            pos = valueEnd + 1
        }
        name = tagName
        attributes = attrs
        textValue = nil
        eventType = XmlPullParser.START_TAG
        pendingEndTag = selfClosing ? tagName : nil
        return XmlPullParser.START_TAG
    }

    @discardableResult
    public func next() throws -> Int {
        if eventType == XmlPullParser.END_DOCUMENT {
            throw XmlPullParserException("no more events (parser is at END_DOCUMENT)")
        }
        if let pending = pendingEndTag {
            // self-closing start tag: report its implicit end tag now
            name = pending
            pendingEndTag = nil
            attributes = nil
            textValue = nil
            eventType = XmlPullParser.END_TAG
            return XmlPullParser.END_TAG
        }
        while pos < units.count {
            if units[pos] == 0x3C {  // "<"
                if startsWith("<!--", at: pos) {
                    skipPast("-->")
                    continue
                }
                if startsWith("<![CDATA[", at: pos) {
                    let cdataStart = pos + 9
                    var cdataEnd = indexOf("]]>", from: cdataStart)
                    if cdataEnd < 0 { cdataEnd = units.count }
                    textValue = substring(cdataStart, cdataEnd)
                    pos = min(cdataEnd + 3, units.count)
                    name = nil
                    attributes = nil
                    eventType = XmlPullParser.TEXT
                    return XmlPullParser.TEXT
                }
                if startsWith("<?", at: pos) {
                    skipPast("?>")
                    continue
                }
                if startsWith("<!", at: pos) {
                    // DOCTYPE: skip to the matching '>'
                    var gt = pos
                    while gt < units.count && units[gt] != 0x3E { gt += 1 }
                    pos = gt < units.count ? gt + 1 : units.count
                    continue
                }
                if startsWith("</", at: pos) {
                    pos += 2
                    let endStart = pos
                    var endGt = pos
                    while endGt < units.count && units[endGt] != 0x3E { endGt += 1 }
                    name = substring(endStart, endGt).trimmingTrailingWhitespace()
                    pos = min(endGt + 1, units.count)
                    textValue = nil
                    attributes = nil
                    eventType = XmlPullParser.END_TAG
                    return XmlPullParser.END_TAG
                }
                return parseStartTag()
            }
            let textStart = pos
            var lt = pos
            while lt < units.count && units[lt] != 0x3C { lt += 1 }
            textValue = XmlPullParser.decodeEntities(substring(textStart, lt))
            pos = lt
            name = nil
            attributes = nil
            eventType = XmlPullParser.TEXT
            return XmlPullParser.TEXT
        }
        endEmitted = true
        eventType = XmlPullParser.END_DOCUMENT
        name = nil
        textValue = nil
        attributes = nil
        return XmlPullParser.END_DOCUMENT
    }

    @discardableResult
    public func nextTag() throws -> Int {
        var event = try next()
        while event == XmlPullParser.TEXT && (textValue ?? "").allSatisfy({ $0 == " " || $0 == "\t" || $0 == "\r" || $0 == "\n" }) {
            event = try next()
        }
        if event != XmlPullParser.START_TAG && event != XmlPullParser.END_TAG {
            throw XmlPullParserException("expected start or end tag (got event \(event))")
        }
        return event
    }

    public func require(_ eventType: Int, _ namespace: String?, _ tagName: String?) throws {
        if self.eventType != eventType || (tagName != nil && name != tagName) {
            let expectedName = tagName ?? "nil"
            let actualName = name ?? "nil"
            throw XmlPullParserException("expected \(expectedName) (\(eventType)) but got \(actualName) (\(self.eventType))")
        }
    }
}

private extension String {
    func trimmingTrailingWhitespace() -> String {
        var end = endIndex
        while end > startIndex {
            let previous = index(before: end)
            let character = self[previous]
            if character == " " || character == "\t" || character == "\r" || character == "\n" {
                end = previous
            } else {
                break
            }
        }
        return String(self[startIndex..<end])
    }
}

// Port of `src/js/core/io/io.js` — the ORIPA.io facade (Java EditorActivity/PaintCpFragment
// call sites) and its Java `Double.toString`/UTF-8 helpers.
//
// Swift boundary API (contract §5.1):
//   OripaIO.loadCreasePattern(data:fileType:)  -> CreasePattern (external load, modified = true)
//   OripaIO.loadCreasePattern(data:filenameWithExt:)
//   OripaIO.loadCreasePatternForce(data:)      -> CreasePattern (internal OPXC, modified untouched)
//   OripaIO.readCreasePatternFile(data:filename:)
//   OripaIO.exportCp / exportOpx / exportOpxc  -> Data
//   OripaIO.exportSvg / exportFoldedModelSvg   -> String
// PNG export lives in ORIPAUI (`CPPNGExport`/`FoldPNGExport`) because it needs rendering.
//
// Format detection mirrors the JS `detectFileType` (sniff the first 512 characters) so that
// extension-less internal project files (always OPXC) and imported files keep working.
import Foundation

/// Errors thrown by the IO layer. The descriptions keep the Java/JS exception names
/// (`NumberFormatException`, `XmlPullParserException`) that the reference tests match on.
public enum OripaIOError: Error, CustomStringConvertible {
    case numberFormat(String)
    case xmlPullParser(String)
    case unsupportedFileType(String)
    case runtime(String)

    public var description: String {
        switch self {
        case .numberFormat(let text): return "NumberFormatException: " + text
        case .xmlPullParser(let text): return "XmlPullParserException: " + text
        case .unsupportedFileType(let text): return "ORIPA.io: unsupported crease pattern file type: " + text
        case .runtime(let text): return "ORIPA.io: " + text
        }
    }
}

// MARK: - Java number parsing

/// Java `Byte.parseByte` / `Double.parseDouble` (strict syntax; JS reference re-implements both
/// with regular expressions) plus the lenient `Float.parseFloat`/`Integer.parseInt` prefix
/// parsing used by `LoaderOpxcToGL`.
public enum JavaNumberFormat {
    private static func numberFormat(_ text: String) -> OripaIOError {
        .numberFormat(text)
    }

    /// Java `Byte.parseByte(String)`.
    public static func parseByte(_ text: String) throws -> Int {
        guard isValidIntegerSyntax(text) else { throw numberFormat(text) }
        guard let value = Int(text), value >= -128, value <= 127 else { throw numberFormat(text) }
        return value
    }

    /// Java `Double.parseDouble(String)`.
    public static func parseDouble(_ text: String) throws -> Double {
        if text == "NaN" { return .nan }
        if text == "Infinity" || text == "+Infinity" { return .infinity }
        if text == "-Infinity" { return -.infinity }
        guard isValidFloatingSyntax(text), let value = Double(text) else { throw numberFormat(text) }
        return value
    }

    private static func isValidIntegerSyntax(_ text: String) -> Bool {
        var index = text.startIndex
        if index < text.endIndex, text[index] == "+" || text[index] == "-" {
            index = text.index(after: index)
        }
        guard index < text.endIndex else { return false }
        while index < text.endIndex {
            let character = text[index]
            guard character.isASCII, character.isNumber else { return false }
            index = text.index(after: index)
        }
        return true
    }

    /// `^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?$`
    private static func isValidFloatingSyntax(_ text: String) -> Bool {
        var index = text.startIndex
        if index < text.endIndex, text[index] == "+" || text[index] == "-" {
            index = text.index(after: index)
        }
        var integerDigits = 0
        while index < text.endIndex, text[index].isASCII, text[index].isNumber {
            integerDigits += 1
            index = text.index(after: index)
        }
        var fractionDigits = 0
        if index < text.endIndex, text[index] == "." {
            index = text.index(after: index)
            while index < text.endIndex, text[index].isASCII, text[index].isNumber {
                fractionDigits += 1
                index = text.index(after: index)
            }
        }
        guard integerDigits > 0 || fractionDigits > 0 else { return false }
        if index < text.endIndex, text[index] == "e" || text[index] == "E" {
            index = text.index(after: index)
            if index < text.endIndex, text[index] == "+" || text[index] == "-" {
                index = text.index(after: index)
            }
            var exponentDigits = 0
            while index < text.endIndex, text[index].isASCII, text[index].isNumber {
                exponentDigits += 1
                index = text.index(after: index)
            }
            guard exponentDigits > 0 else { return false }
        }
        return index == text.endIndex
    }

    /// Java `Float.parseFloat` lenient prefix parse (used by `LoaderOpxcToGL`, which in the JS
    /// reference calls the built-in `parseFloat`): longest valid numeric prefix, NaN otherwise.
    public static func parseFloatLenient(_ text: String) -> Double {
        let scalars = Array(text)
        var index = 0
        var signPrefix = ""
        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" {
            signPrefix = String(scalars[index])
            index += 1
        }
        var digits = 0
        var result = signPrefix
        while index < scalars.count, scalars[index].isASCII, scalars[index].isNumber {
            result.append(scalars[index])
            digits += 1
            index += 1
        }
        if index < scalars.count, scalars[index] == "." {
            var fraction = "."
            var fractionDigits = 0
            var lookahead = index + 1
            while lookahead < scalars.count, scalars[lookahead].isASCII, scalars[lookahead].isNumber {
                fraction.append(scalars[lookahead])
                fractionDigits += 1
                lookahead += 1
            }
            if digits > 0 || fractionDigits > 0 {
                result += fraction
                digits += fractionDigits
                index = lookahead
            }
        }
        guard digits > 0 else { return .nan }
        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            var exponent = String(scalars[index])
            var lookahead = index + 1
            if lookahead < scalars.count, scalars[lookahead] == "+" || scalars[lookahead] == "-" {
                exponent.append(scalars[lookahead])
                lookahead += 1
            }
            var exponentDigits = 0
            while lookahead < scalars.count, scalars[lookahead].isASCII, scalars[lookahead].isNumber {
                exponent.append(scalars[lookahead])
                exponentDigits += 1
                lookahead += 1
            }
            if exponentDigits > 0 { result += exponent }
        }
        return Double(result) ?? .nan
    }

    /// Java `Integer.parseInt` lenient prefix parse (radix 10) used by `LoaderOpxcToGL`.
    public static func parseIntLenient(_ text: String) -> Int {
        let scalars = Array(text)
        var index = 0
        var sign = 1
        if index < scalars.count, scalars[index] == "+" {
            index += 1
        } else if index < scalars.count, scalars[index] == "-" {
            sign = -1
            index += 1
        }
        var value = 0
        var digits = 0
        while index < scalars.count, scalars[index].isASCII, scalars[index].isNumber {
            value = value * 10 + Int(scalars[index].asciiValue! - 48)
            digits += 1
            index += 1
        }
        return digits == 0 ? 0 : value * sign
    }

    /// JS `Math.min` / `Math.max` NaN propagation for the lenient `LoaderOpxcToGL` path.
    @inline(__always)
    static func jsMin(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN { return .nan }
        return Swift.min(a, b)
    }

    @inline(__always)
    static func jsMax(_ a: Double, _ b: Double) -> Double {
        if a.isNaN || b.isNaN { return .nan }
        return Swift.max(a, b)
    }
}

// MARK: - Facade

/// Options for `exportFoldedModelSvg` (JS: `{ wire, flip, frontColor, backColor, lineColor }`).
public struct FoldedModelSvgOptions {
    /// Android `FoldCpOverlapSettingsDialogFragment` defaults.
    public static let defaultFrontColor = -28242
    public static let defaultBackColor = -16730151
    public static let defaultLineColor = -11513776

    public var wire: Bool
    public var flip: Bool
    public var frontColor: Int?
    public var backColor: Int?
    public var lineColor: Int?

    public init(
        wire: Bool = false,
        flip: Bool = false,
        frontColor: Int? = nil,
        backColor: Int? = nil,
        lineColor: Int? = nil
    ) {
        self.wire = wire
        self.flip = flip
        self.frontColor = frontColor
        self.backColor = backColor
        self.lineColor = lineColor
    }
}

public enum OripaIO {
    // MARK: - byte/text helpers

    public static func textToBytes(_ text: String) -> Data {
        Data(text.utf8)
    }

    public static func bytesToText(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8) { return text }
        return String(data: data, encoding: .isoLatin1) ?? ""
    }

    /// Java `Double.toString` emulation (the Android exporters' number format):
    /// plain decimal with at least one fractional digit for `1e-3 <= |d| < 1e7`,
    /// scientific (`"1.0E-4"`, `"1.0E7"`) otherwise. Exact for every finite double:
    /// the shortest round-tripping decimal digits are used, like `Number#toString`.
    public static func doubleToString(_ value: Double) -> String {
        let d = value
        if d.isNaN { return "NaN" }
        if d == .infinity { return "Infinity" }
        if d == -.infinity { return "-Infinity" }
        if d == 0 { return d.sign == .minus ? "-0.0" : "0.0" }
        let negative = d < 0
        let magnitude = abs(d)
        let scientific = shortestScientific(magnitude)
        if magnitude >= 1e-3 && magnitude < 1e7 {
            let plain = plainDecimal(scientific.digits, scientific.exponent)
            // JS `String(d)` has no exponent in this range; append one fractional digit.
            let plainWithFraction = plain.contains(".") ? plain : plain + ".0"
            return (negative ? "-" : "") + plainWithFraction
        }
        var mantissa = String(scientific.digits.first!)
        let rest = String(scientific.digits.dropFirst())
        mantissa += "." + (rest.isEmpty ? "0" : rest)
        return (negative ? "-" : "") + mantissa + "E" + String(scientific.exponent)
    }

    private static func shortestScientific(_ magnitude: Double) -> (digits: String, exponent: Int) {
        // NB: String(format:) must be used WITHOUT a locale argument; the locale overload
        // mishandles large `%e` precisions on macOS (rounds 9.999999999999998e6 to 1e7).
        var candidate = ""
        for length in 1...17 {
            let text = String(format: "%.\(length - 1)e", magnitude)
            if Double(text) == magnitude {
                candidate = text
                break
            }
        }
        if candidate.isEmpty {
            candidate = String(format: "%.16e", magnitude)
        }
        // "1.23456789e+07" -> digits "123456789", exponent 7. The C `%e` output can be
        // denormalized for values that round up at the requested precision
        // (e.g. "0.099999999999999980E+08"), so strip leading zeros (adjusting the
        // exponent) and insignificant trailing zeros.
        let lowercase = candidate.lowercased()
        let parts = lowercase.split(separator: "e")
        let mantissa = parts[0]
        var exponent = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var digits = Array(String(mantissa.filter { $0.isNumber }))
        while digits.count > 1 && digits.first == "0" {
            digits.removeFirst()
            exponent -= 1
        }
        while digits.count > 1 && digits.last == "0" {
            digits.removeLast()
        }
        return (String(digits), exponent)
    }

    /// Plain decimal layout for `digits * 10^(exponent - digits.count + 1)`:
    /// JS `String(d)` produces no exponent in the `[1e-3, 1e7)` range.
    private static func plainDecimal(_ digits: String, _ exponent: Int) -> String {
        let characters = Array(digits)
        let pointPosition = exponent + 1  // number of digits before the decimal point
        if pointPosition >= characters.count {
            return digits + String(repeating: "0", count: pointPosition - characters.count)
        }
        if pointPosition <= 0 {
            return "0." + String(repeating: "0", count: -pointPosition) + digits
        }
        let integerPart = String(characters[0..<pointPosition])
        let fractionPart = String(characters[pointPosition...])
        return integerPart + "." + fractionPart
    }

    // MARK: - format detection

    /// JS `detectFileType(fileObject)`: sniff the first 512 characters of the content.
    public static func detectFileType(_ data: Data) -> FileType {
        let text = String(bytesToText(data).prefix(512))
        if text.contains("java.beans.XMLDecoder") || text.contains("oripa.OriLineProxy") { return .opx }
        if text.contains("<data") || text.contains("<line") { return .opxc }
        return .cp
    }

    private static func loadByType(_ fileType: FileType, _ filenameWithExt: String, _ data: Data, _ cp: CreasePattern) throws {
        switch fileType {
        case .opx:
            try LoaderOpx.getCreasePattern(filenameWithExt, data, cp)
        case .opxc:
            try LoaderOpxc.getCreasePattern(filenameWithExt, data, cp)
        case .cp:
            try LoaderCp.getCreasePattern(filenameWithExt, data, cp)
        case .png, .svg:
            throw OripaIOError.unsupportedFileType(fileType.getExtension())
        }
    }

    // MARK: - loaders

    /// Load an external crease-pattern file with an explicit format.
    /// JS: `io.loadCreasePattern(filenameWithExt, fileObject, cp)` — marks the CP modified.
    @discardableResult
    public static func loadCreasePattern(data: Data, fileType: FileType) throws -> CreasePattern {
        let cp = CreasePattern()
        try loadByType(fileType, "", data, cp)
        cp.modified = true
        return cp
    }

    /// Load an external file, dispatching on the file extension (content sniffing only when
    /// the name carries no extension, like the JS `fileExtension`+`detectFileType` flow).
    @discardableResult
    public static func loadCreasePattern(data: Data, filenameWithExt: String) throws -> CreasePattern {
        let ext = FileUtil.getFileExt(filenameWithExt)
        if ext.isEmpty {
            return try loadCreasePattern(data: data, fileType: detectFileType(data))
        }
        guard let fileType = FileType.valueOf(ext.uppercased()) else {
            throw OripaIOError.unsupportedFileType(ext)
        }
        return try loadCreasePattern(data: data, fileType: fileType)
    }

    /// Load an internal project file (no extension, always OPXC) without touching `modified`.
    /// JS: `io.loadCreasePatternForce(name, fileObject, cp, [fileType])`.
    @discardableResult
    public static func loadCreasePatternForce(data: Data) throws -> CreasePattern {
        let cp = CreasePattern()
        try loadByType(detectFileType(data), "", data, cp)
        return cp
    }

    @discardableResult
    public static func loadCreasePatternForce(data: Data, fileType: FileType) throws -> CreasePattern {
        let cp = CreasePattern()
        try loadByType(fileType, "", data, cp)
        return cp
    }

    /// Import path used by the project screens: dispatch on the filename extension, sniff when
    /// the name carries none. External imports are considered modified (unsaved).
    @discardableResult
    public static func readCreasePatternFile(data: Data, filename: String) throws -> CreasePattern {
        try loadCreasePattern(data: data, filenameWithExt: filename)
    }

    // MARK: - exporters

    public static func exportCp(_ creasePattern: CreasePattern) -> Data {
        ExporterCp.getCreasePattern(creasePattern)
    }

    public static func exportOpx(_ creasePattern: CreasePattern) -> Data {
        ExporterOpx.getCreasePattern(creasePattern)
    }

    public static func exportOpxc(_ creasePattern: CreasePattern) -> Data {
        ExporterOpxc.getCreasePattern(creasePattern)
    }

    public static func exportSvg(_ creasePattern: CreasePattern) -> String {
        bytesToText(ExporterSvg.getCreasePattern(creasePattern))
    }

    public static func exportSvgData(_ creasePattern: CreasePattern) -> Data {
        ExporterSvg.getCreasePattern(creasePattern)
    }

    /// Paint screen "export CP" dialog dispatch (JS `io.exportCreasePattern`).
    /// PNG is exported by ORIPAUI's `CPPNGExport` and is rejected here.
    public static func exportCreasePattern(_ fileType: FileType, _ creasePattern: CreasePattern) throws -> Data {
        switch fileType {
        case .svg: return ExporterSvg.getCreasePattern(creasePattern)
        case .opx: return ExporterOpx.getCreasePattern(creasePattern)
        case .opxc: return ExporterOpxc.getCreasePattern(creasePattern)
        case .cp: return ExporterCp.getCreasePattern(creasePattern)
        case .png:
            throw OripaIOError.runtime("PNG export is rendered by the UI layer (CPPNGExport)")
        }
    }

    /// Fold screen export (JS `io.exportFoldedModelSvg`): mode 0 xray, 1 overlap,
    /// 2 cross line (the Android app exports the xray SVG for the cross view too).
    public static func exportFoldedModelSvg(
        _ foldedModel: FoldedModel,
        mode: Int,
        options: FoldedModelSvgOptions = FoldedModelSvgOptions()
    ) -> String {
        let data: Data
        if mode == 1 {
            data = ExporterSvg.getFoldedModelOverlap(
                foldedModel,
                options.flip,
                options.frontColor ?? FoldedModelSvgOptions.defaultFrontColor,
                options.backColor ?? FoldedModelSvgOptions.defaultBackColor,
                options.lineColor ?? FoldedModelSvgOptions.defaultLineColor)
        } else if mode == 0 || mode == 2 {
            data = ExporterSvg.getFoldedModelXray(foldedModel, options.wire)
        } else {
            data = ExporterSvg.getBlank()
        }
        return bytesToText(data)
    }
}

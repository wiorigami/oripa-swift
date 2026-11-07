// Port of `src/js/core/io/load/LoaderCp.js` (Java `com.origamitoolbox.oripa.io.load.LoaderCp`).
//
// File format: one line per crease, whitespace separated
//   "type x0 y0 x1 y1"   (type: 0 flat .. 3 valley; 0-lines are skipped by the loader)
// The Android FileReader is replaced by `(filenameWithExt, data, creasePattern)`.
import Foundation

public enum LoaderCp {
    /// Load `.cp` text into `creasePattern` (Android: `getCreasePattern(File dir, String filename, ...)`).
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
        // BufferedReader.readLine(): split on \r\n, \r or \n (no trailing empty line needed).
        let rows = splitReadLines(text)
        for row in rows {
            // Java String.trim() + JS `split(/\s+/)` (both drop leading/trailing whitespace).
            let parts = row.split(whereSeparator: { $0.isWhitespace })
            guard parts.count == 5 else { continue }
            let type = try JavaNumberFormat.parseByte(String(parts[0]))
            if type != 0 {
                let line = OriLine(
                    OriPoint(try JavaNumberFormat.parseDouble(String(parts[1])),
                             try JavaNumberFormat.parseDouble(String(parts[2]))),
                    OriPoint(try JavaNumberFormat.parseDouble(String(parts[3])),
                             try JavaNumberFormat.parseDouble(String(parts[4]))),
                    LineType(rawValue: type) ?? .undefined)
                creasePattern.addLineCheckNoException(line)
            }
        }
    }

    /// JS `text.split(/\r\n|\r|\n/)`.
    static func splitReadLines(_ text: String) -> [String] {
        var lines: [String] = []
        var current = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "\r" {
                lines.append(current)
                current = ""
                index = text.index(after: index)
                if index < text.endIndex, text[index] == "\n" {
                    index = text.index(after: index)
                }
            } else if character == "\n" {
                lines.append(current)
                current = ""
                index = text.index(after: index)
            } else {
                current.append(character)
                index = text.index(after: index)
            }
        }
        lines.append(current)
        return lines
    }
}

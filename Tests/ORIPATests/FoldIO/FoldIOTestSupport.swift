// Shared helpers for the fold-io golden tests.
//
// Decodes `Fixtures/foldio/*.json` (generated from the reference JS implementation by
// tools/fixtures/foldio/gen_foldio.js) through JSONSerialization and provides the small
// comparison helpers the IO / render-data / oracle suites need.
import Foundation
import ORIPACore

enum FoldIOTestSupport {
    // MARK: - JSON

    static func json(_ relativePath: String) throws -> [String: Any] {
        let data = try Fixtures.data(relativePath)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FoldIOTestSupport", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "fixture is not a JSON object: \(relativePath)"])
        }
        return object
    }

    static func dict(_ any: Any?) -> [String: Any] {
        (any as? [String: Any]) ?? [:]
    }

    static func array(_ any: Any?) -> [Any] {
        (any as? [Any]) ?? []
    }

    static func d(_ any: Any?) -> Double {
        if let number = any as? NSNumber { return number.doubleValue }
        if let value = any as? Double { return value }
        if let value = any as? Int { return Double(value) }
        return .nan
    }

    static func i(_ any: Any?) -> Int {
        if let number = any as? NSNumber { return number.intValue }
        if let value = any as? Int { return value }
        return 0
    }

    static func s(_ any: Any?) -> String {
        (any as? String) ?? ""
    }

    static func b(_ any: Any?) -> Bool {
        if let number = any as? NSNumber { return number.boolValue }
        return (any as? Bool) ?? false
    }

    static func doubles(_ any: Any?) -> [Double] {
        array(any).map { d($0) }
    }

    static func ints(_ any: Any?) -> [Int] {
        array(any).map { i($0) }
    }

    // MARK: - crease-pattern line snapshots

    struct Pt: Equatable {
        var x: Double
        var y: Double
    }

    struct LineDump: Equatable {
        var type: Int
        var start: Pt
        var end: Pt
    }

    static func parsePoint(_ any: Any?) -> Pt {
        let object = dict(any)
        return Pt(x: d(object["x"]), y: d(object["y"]))
    }

    static func parseLine(_ any: Any?) -> LineDump {
        let object = dict(any)
        return LineDump(type: i(object["type"]), start: parsePoint(object["start"]), end: parsePoint(object["end"]))
    }

    static func parseLines(_ any: Any?) -> [LineDump] {
        array(any).map(parseLine)
    }

    static func dumpLines(_ creasePattern: CreasePattern) -> [LineDump] {
        creasePattern.lineMVFB.map { line in
            LineDump(type: line.typeValue,
                     start: Pt(x: line.start.x, y: line.start.y),
                     end: Pt(x: line.end.x, y: line.end.y))
        }
    }

    static func dumpPoints(_ creasePattern: CreasePattern) -> [Pt] {
        creasePattern.points.map { Pt(x: $0.x, y: $0.y) }
    }

    // MARK: - case files

    static func caseURL(_ name: String) -> URL {
        Fixtures.url("Fixtures/cases/" + name)
    }

    /// Load a `Fixtures/cases/**` file through the IO facade (same dispatch as the app).
    static func loadCase(_ name: String) throws -> CreasePattern {
        let data = try Data(contentsOf: caseURL(name))
        let fileType: FileType
        if name.lowercased().hasSuffix(".opx") {
            fileType = .opx
        } else if name.lowercased().hasSuffix(".opxc") {
            fileType = .opxc
        } else {
            fileType = .cp
        }
        return try OripaIO.loadCreasePattern(data: data, fileType: fileType)
    }

    // MARK: - comparisons

    static func expectLines(
        _ h: TestHarness,
        _ actual: [LineDump],
        _ expected: [LineDump],
        _ label: @autoclosure () -> String
    ) {
        h.expectEqual(actual.count, expected.count, "\(label()): line count")
        let count = min(actual.count, expected.count)
        for index in 0..<count where actual[index] != expected[index] {
            h.fail("\(label()): line \(index) mismatch actual=\(actual[index]) expected=\(expected[index])")
            return
        }
    }

    static func expectDoubleArray(
        _ h: TestHarness,
        _ actual: [Double],
        _ expected: [Any],
        accuracy: Double = 0,
        _ label: @autoclosure () -> String
    ) {
        let expectedDoubles = expected.map { d($0) }
        h.expectEqual(actual.count, expectedDoubles.count, "\(label()): count")
        let count = min(actual.count, expectedDoubles.count)
        for index in 0..<count where !(actual[index] == expectedDoubles[index] ||
            abs(actual[index] - expectedDoubles[index]) <= accuracy) {
            h.fail("\(label()): [\(index)] expected \(expectedDoubles[index]) got \(actual[index])")
            return
        }
    }

    /// The JS reference stores plain JS numbers in the render-data arrays while the Java
    /// encodings (kept by the Swift port) are float32, so float arrays compare with a
    /// float32-precision tolerance by default.
    static func expectFloatArray(
        _ h: TestHarness,
        _ actual: [Float],
        _ expected: [Any],
        accuracy: Double = 1e-4,
        _ label: @autoclosure () -> String
    ) {
        let expectedDoubles = expected.map { d($0) }
        h.expectEqual(actual.count, expectedDoubles.count, "\(label()): count")
        let count = min(actual.count, expectedDoubles.count)
        for index in 0..<count where !(Double(actual[index]) == expectedDoubles[index] ||
            abs(Double(actual[index]) - expectedDoubles[index]) <= accuracy) {
            h.fail("\(label()): [\(index)] expected \(expectedDoubles[index]) got \(actual[index])")
            return
        }
    }

    static func expectIntArray(
        _ h: TestHarness,
        _ actual: [Int],
        _ expected: [Any],
        _ label: @autoclosure () -> String
    ) {
        let expectedInts = expected.map { i($0) }
        h.expectEqual(actual.count, expectedInts.count, "\(label()): count")
        let count = min(actual.count, expectedInts.count)
        for index in 0..<count where actual[index] != expectedInts[index] {
            h.fail("\(label()): [\(index)] expected \(expectedInts[index]) got \(actual[index])")
            return
        }
    }

    static func expectIntArray(
        _ h: TestHarness,
        _ actual: [Int],
        _ expected: [Int],
        _ label: @autoclosure () -> String
    ) {
        h.expectEqual(actual.count, expected.count, "\(label()): count")
        let count = min(actual.count, expected.count)
        for index in 0..<count where actual[index] != expected[index] {
            h.fail("\(label()): [\(index)] expected \(expected[index]) got \(actual[index])")
            return
        }
    }

    /// Overlap/shadow vertex angles are stored in tenths of a degree. The reference JS uses
    /// V8's fdlibm sin/cos/atan2 while Swift uses the system libm, so values can differ by one
    /// last ulp and truncate to a neighbouring integer; also +180 and -180 are the same
    /// direction. Compare modulo 360 degrees with a 0.1-degree tolerance.
    static func expectAngleArray(
        _ h: TestHarness,
        _ actual: [Float],
        _ expected: [Any],
        accuracy: Double = 1.0,
        _ label: @autoclosure () -> String
    ) {
        let expectedDoubles = expected.map { d($0) }
        h.expectEqual(actual.count, expectedDoubles.count, "\(label()): count")
        let count = min(actual.count, expectedDoubles.count)
        for index in 0..<count {
            let a = normalizedAngleTenths(Double(actual[index]))
            let b = normalizedAngleTenths(expectedDoubles[index])
            var difference = abs(a - b)
            if difference > 1800 { difference = 3600 - difference }
            if difference > accuracy {
                h.fail("\(label()): [\(index)] expected \(expectedDoubles[index]) got \(actual[index])")
                return
            }
        }
    }

    private static func normalizedAngleTenths(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 3600)
        if result > 1800 { result -= 3600 }
        if result <= -1800 { result += 3600 }
        return result
    }

    static func expectByteArray(
        _ h: TestHarness,
        _ actual: [UInt8],
        _ expected: [Any],
        _ label: @autoclosure () -> String
    ) {
        let expectedInts = expected.map { i($0) }
        h.expectEqual(actual.count, expectedInts.count, "\(label()): count")
        let count = min(actual.count, expectedInts.count)
        for index in 0..<count where Int(actual[index]) != expectedInts[index] {
            h.fail("\(label()): [\(index)] expected \(expectedInts[index]) got \(actual[index])")
            return
        }
    }
}

// MARK: - model construction for render-data tests

extension FoldIOTestSupport {
    /// Build a `FoldedModel` from an `engine.json`-style entry (`facesCheck` + half size arg).
    static func buildFoldedModel(_ modelObject: [String: Any]) throws -> FoldedModel {
        let polygons: [OriPolygon] = array(modelObject["facesCheck"]).map { entry in
            let object = dict(entry)
            let points: [OriPoint] = array(object["points"]).map { pointEntry in
                let point = dict(pointEntry)
                return OriPoint(d(point["x"]), d(point["y"]))
            }
            let lineTypes = ints(object["lineTypes"])
            return OriPolygon(points, lineTypes)
        }
        let halfSize = d(modelObject["foldedModelHalfSizeArgument"])
        let model = FoldedModel(foldedModelHalfSize: halfSize)
        let pattern = CreasePattern()
        pattern.facesCheck = polygons
        model.foldWithoutOverlap(pattern)
        model.foldWithOverlap()
        return model
    }

    /// Compare one GLDataFmOverlap set against its JSON dump (full or compact form).
    static func expectOverlap(
        _ h: TestHarness,
        _ data: GLDataFmOverlap,
        _ expected: [String: Any],
        _ label: @autoclosure () -> String
    ) {
        if b(expected["compact"]) {
            let labelText = label()
            // Positions are float32 encodings of the JS doubles; angles are tenths of a degree.
            for name in ["pointPosition", "reversePointPosition"] {
                let actual: [Float] = name == "pointPosition" ? data.pointPosition : data.reversePointPosition
                h.expectEqual(actual.count, i(expected[name + "Length"]), "\(labelText).\(name) length")
                expectFloatArray(h, Array(actual.prefix(32)), array(expected[name + "Sample"]),
                                 "\(labelText).\(name) sample")
            }
            for name in ["pointAngleDeg", "reversePointAngleDeg"] {
                let actual: [Float] = name == "pointAngleDeg" ? data.pointAngleDeg : data.reversePointAngleDeg
                h.expectEqual(actual.count, i(expected[name + "Length"]), "\(labelText).\(name) length")
                expectAngleArray(h, Array(actual.prefix(32)), array(expected[name + "Sample"]),
                                 "\(labelText).\(name) sample")
            }
            for name in ["pointType", "reversePointType"] {
                let actual: [UInt8] = name == "pointType" ? data.pointType : data.reversePointType
                h.expectEqual(actual.count, i(expected[name + "Length"]), "\(labelText).\(name) length")
                expectByteArray(h, Array(actual.prefix(32)), array(expected[name + "Sample"]),
                                "\(labelText).\(name) sample")
            }
            for name in ["drawOrder", "reverseDrawOrder"] {
                let actual: [Int] = name == "drawOrder" ? data.drawOrder : data.reverseDrawOrder
                h.expectEqual(actual.count, i(expected[name + "Length"]), "\(labelText).\(name) length")
                expectIntArray(h, Array(actual.prefix(32)), array(expected[name + "Sample"]),
                               "\(labelText).\(name) sample")
            }
        } else {
            expectFloatArray(h, data.pointPosition, array(expected["pointPosition"]),
                             "\(label()).pointPosition")
            expectByteArray(h, data.pointType, array(expected["pointType"]), "\(label()).pointType")
            expectAngleArray(h, data.pointAngleDeg, array(expected["pointAngleDeg"]),
                             "\(label()).pointAngleDeg")
            expectIntArray(h, data.drawOrder, array(expected["drawOrder"]), "\(label()).drawOrder")
            expectFloatArray(h, data.reversePointPosition, array(expected["reversePointPosition"]),
                             "\(label()).reversePointPosition")
            expectByteArray(h, data.reversePointType, array(expected["reversePointType"]),
                            "\(label()).reversePointType")
            expectAngleArray(h, data.reversePointAngleDeg, array(expected["reversePointAngleDeg"]),
                             "\(label()).reversePointAngleDeg")
            expectIntArray(h, data.reverseDrawOrder, array(expected["reverseDrawOrder"]),
                           "\(label()).reverseDrawOrder")
        }
    }
}

// MARK: - SVG comparison

extension FoldIOTestSupport {
    /// Exact comparison when possible; otherwise compare structure (numbers masked) and every
    /// numeric attribute with `accuracy`. Needed for folded-model SVG: the reference JS keeps
    /// full doubles where the Java/Android exporters wrote floats, so last-digit formatting
    /// can differ while the geometry is identical.
    static func expectSvg(
        _ h: TestHarness,
        _ actual: String,
        _ expected: String,
        accuracy: Double = 1e-4,
        _ label: @autoclosure () -> String
    ) {
        if actual == expected {
            h.expect(true, "\(label())")
            return
        }
        let actualNumbers = svgNumbers(actual)
        let expectedNumbers = svgNumbers(expected)
        h.expectEqual(actualNumbers.count, expectedNumbers.count, "\(label()): numeric token count")
        let count = min(actualNumbers.count, expectedNumbers.count)
        for index in 0..<count where abs(actualNumbers[index] - expectedNumbers[index]) > accuracy {
            h.fail("\(label()): number[\(index)] expected \(expectedNumbers[index]) got \(actualNumbers[index])")
            return
        }
        h.expectEqual(maskSvgNumbers(actual), maskSvgNumbers(expected), "\(label()): non-numeric structure")
    }

    static func svgNumbers(_ text: String) -> [Double] {
        var numbers: [Double] = []
        var current = ""
        var inNumber = false
        for character in text {
            let isNumberCharacter = character.isNumber || character == "." || character == "-" ||
                character == "+" || character == "e" || character == "E"
            if isNumberCharacter {
                current.append(character)
                inNumber = true
            } else if inNumber {
                if let value = Double(current) { numbers.append(value) }
                current = ""
                inNumber = false
            }
        }
        if inNumber, let value = Double(current) { numbers.append(value) }
        return numbers
    }

    static func maskSvgNumbers(_ text: String) -> String {
        var result = ""
        var inNumber = false
        for character in text {
            let isNumberCharacter = character.isNumber || character == "." || character == "-" ||
                character == "+" || character == "e" || character == "E"
            if isNumberCharacter {
                if !inNumber {
                    result.append("#")
                    inNumber = true
                }
            } else {
                inNumber = false
                result.append(character)
            }
        }
        return result
    }
}

// fold-io file-format golden tests (port of oripa-port/tools/tests/test_fold_io_roundtrip.js).
//
// Fixtures/foldio/roundtrip.json holds the expected CP/OPX/OPXC/SVG bytes, line snapshots,
// FileUtil results, LoaderOpxcToGL arrays and malformed-input behaviour, generated from the
// reference JavaScript implementation.
import Foundation
import ORIPACore

enum FoldIOIOTests {
    static var all: [TestSuite] {
        [
            TestSuite("FoldIO.IO.doubleToString") { h in try doubleToString(h) },
            TestSuite("FoldIO.IO.fileUtil") { h in try fileUtil(h) },
            TestSuite("FoldIO.IO.xmlPullParser") { h in try xmlPullParser(h) },
            TestSuite("FoldIO.IO.creasePatternRoundtrip") { h in try creasePatternRoundtrip(h) },
            TestSuite("FoldIO.IO.forceLoad") { h in try forceLoad(h) },
            TestSuite("FoldIO.IO.opxLoaderTolerance") { h in try opxLoaderTolerance(h) },
            TestSuite("FoldIO.IO.malformedInput") { h in try malformedInput(h) },
            TestSuite("FoldIO.IO.loaderOpxcToGL") { h in try loaderOpxcToGL(h) },
            TestSuite("FoldIO.IO.exporterNaming") { h in try exporterNaming(h) },
            TestSuite("FoldIO.IO.miscCoverage") { h in try miscCoverage(h) },
        ]
    }

    // MARK: - Java Double.toString

    private static func doubleToString(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        for entry in FoldIOTestSupport.array(fixture["doubleToString"]) {
            let object = FoldIOTestSupport.dict(entry)
            let inputText = FoldIOTestSupport.s(object["input"])
            let expected = FoldIOTestSupport.s(object["expected"])
            guard let input = Double(inputText) else {
                h.fail("cannot parse double input \(inputText)")
                continue
            }
            h.expectEqual(OripaIO.doubleToString(input), expected, "doubleToString(\(inputText))")
        }
        // spot checks for the exact Java layout
        h.expectEqual(OripaIO.doubleToString(400.0), "400.0")
        h.expectEqual(OripaIO.doubleToString(0.0), "0.0")
        h.expectEqual(OripaIO.doubleToString(-0.0), "-0.0")
        h.expectEqual(OripaIO.doubleToString(0.0001), "1.0E-4")
        h.expectEqual(OripaIO.doubleToString(1e7), "1.0E7")
        h.expectEqual(OripaIO.doubleToString(123.456), "123.456")
        h.expectEqual(OripaIO.doubleToString(.infinity), "Infinity")
        h.expectEqual(OripaIO.doubleToString(.nan), "NaN")
    }

    // MARK: - FileUtil

    private static func fileUtil(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        let fileUtil = FoldIOTestSupport.dict(fixture["fileUtil"])
        for entry in FoldIOTestSupport.array(fileUtil["fileExt"]) {
            let object = FoldIOTestSupport.dict(entry)
            h.expectEqual(FileUtil.getFileExt(FoldIOTestSupport.s(object["input"])),
                          FoldIOTestSupport.s(object["expected"]),
                          "getFileExt(\(FoldIOTestSupport.s(object["input"])))")
        }
        for entry in FoldIOTestSupport.array(fileUtil["filenameNoExt"]) {
            let object = FoldIOTestSupport.dict(entry)
            h.expectEqual(FileUtil.getFilenameNoExt(FoldIOTestSupport.s(object["input"])),
                          FoldIOTestSupport.s(object["expected"]),
                          "getFilenameNoExt(\(FoldIOTestSupport.s(object["input"])))")
        }
        for entry in FoldIOTestSupport.array(fileUtil["filenameWithExt"]) {
            let object = FoldIOTestSupport.dict(entry)
            let typeName = FoldIOTestSupport.s(object["fileType"])
            guard let fileType = FileType.valueOf(typeName) else {
                h.fail("unknown FileType \(typeName)")
                continue
            }
            h.expectEqual(FileUtil.getFilenameWithExt(fileType, FoldIOTestSupport.s(object["name"])),
                          FoldIOTestSupport.s(object["expected"]),
                          "getFilenameWithExt(\(typeName))")
        }
        for entry in FoldIOTestSupport.array(fileUtil["mimeType"]) {
            let object = FoldIOTestSupport.dict(entry)
            let input = FoldIOTestSupport.s(object["input"])
            let expected = object["expected"]
            if expected is NSNull {
                h.expectNil(FileUtil.getMimeType(input), "getMimeType(\(input)) should be nil")
            } else {
                h.expectEqual(FileUtil.getMimeType(input), FoldIOTestSupport.s(expected), "getMimeType(\(input))")
            }
        }
    }

    // MARK: - XmlPullParser

    private static func xmlPullParser(_ h: TestHarness) throws {
        let parser = XmlPullParser()
        parser.setInput("<?xml version='1.0'?>\n<!-- comment --><root a=\"1\" b='x &amp; y'>" +
            "<child k=\"2\"/><n>5</n><![CDATA[raw]]></root>")
        h.expectEqual(parser.getEventType(), XmlPullParser.START_DOCUMENT, "START_DOCUMENT")
        h.expectEqual(try parser.nextTag(), XmlPullParser.START_TAG, "root start tag")
        h.expectEqual(parser.getName(), "root", "root name")
        h.expectEqual(parser.getAttributeValue(nil, "a"), "1", "attribute a")
        h.expectEqual(parser.getAttributeValue(nil, "b"), "x & y", "attribute b entity decoding")
        h.expectEqual(try parser.nextTag(), XmlPullParser.START_TAG, "child start tag")
        h.expectEqual(parser.getName(), "child", "child name")
        h.expectEqual(parser.getAttributeValue(nil, "k"), "2", "attribute k")
        h.expectEqual(try parser.nextTag(), XmlPullParser.END_TAG, "implicit end tag of self-closing element")
        h.expectEqual(parser.getName(), "child", "self-closing end name")
        h.expectEqual(try parser.nextTag(), XmlPullParser.START_TAG, "n start tag")
        h.expectEqual(try parser.next(), XmlPullParser.TEXT, "text event")
        h.expectEqual(parser.getText(), "5", "text value")
        _ = try parser.nextTag()
        try parser.require(XmlPullParser.END_TAG, nil, "n")
        h.expectEqual(try parser.next(), XmlPullParser.TEXT, "cdata text event")
        h.expectEqual(parser.getText(), "raw", "CDATA content")
        h.expectEqual(try parser.next(), XmlPullParser.END_TAG, "root end tag")
        try parser.require(XmlPullParser.END_TAG, nil, "root")
        var threw = false
        do {
            try parser.require(XmlPullParser.START_TAG, nil, "root")
        } catch let error as XmlPullParserException {
            threw = error.description.contains("XmlPullParserException")
        }
        h.expect(threw, "require throws XmlPullParserException on mismatch")
        h.expectEqual(try parser.next(), XmlPullParser.END_DOCUMENT, "END_DOCUMENT")
    }

    // MARK: - CP / OPX / OPXC / SVG round-trips

    private static func creasePatternRoundtrip(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        let cases = FoldIOTestSupport.array(fixture["cpCases"])
        h.expectEqual(cases.count, 3, "three CP round-trip cases")
        for entry in cases {
            let object = FoldIOTestSupport.dict(entry)
            let name = FoldIOTestSupport.s(object["name"])
            let expectedLines = FoldIOTestSupport.parseLines(object["lines"])
            let expectedPoints = FoldIOTestSupport.array(object["points"]).map { FoldIOTestSupport.parsePoint($0) }
            let exports = FoldIOTestSupport.dict(object["exports"])
            let loadedLines = FoldIOTestSupport.dict(object["loadedLines"])
            let reexportIdentical = FoldIOTestSupport.dict(object["reexportIdentical"])

            // build the same CP in Swift and compare the (ordered) line snapshot
            let cp: CreasePattern
            switch name {
            case "segmentedSquare": cp = buildCreasePatternSegmented()
            case "mixedTypes": cp = buildCreasePatternMixed()
            default: cp = buildCreasePatternSmall()
            }
            FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(cp), expectedLines, "\(name): lineMVFB")
            h.expectEqual(FoldIOTestSupport.dumpPoints(cp).count, expectedPoints.count, "\(name): pointMVFB count")
            for (index, point) in FoldIOTestSupport.dumpPoints(cp).enumerated() where index < expectedPoints.count {
                if point != expectedPoints[index] {
                    h.fail("\(name): pointMVFB[\(index)] mismatch")
                    break
                }
            }

            // exact export bytes for every format
            h.expectEqual(OripaIO.bytesToText(OripaIO.exportOpx(cp)),
                          FoldIOTestSupport.s(exports["opx"]), "\(name): opx export")
            h.expectEqual(OripaIO.bytesToText(OripaIO.exportOpxc(cp)),
                          FoldIOTestSupport.s(exports["opxc"]), "\(name): opxc export")
            h.expectEqual(OripaIO.bytesToText(OripaIO.exportCp(cp)),
                          FoldIOTestSupport.s(exports["cp"]), "\(name): cp export")
            h.expectEqual(OripaIO.exportSvg(cp), FoldIOTestSupport.s(exports["svg"]), "\(name): svg export")

            // load -> same line set, and re-export is byte-identical
            for fileType in [FileType.opx, .opxc, .cp] {
                let typeName = fileType.getExtension()
                let bytes = try OripaIO.exportCreasePattern(fileType, cp)
                let loaded = try OripaIO.loadCreasePattern(data: bytes, fileType: fileType)
                FoldIOTestSupport.expectLines(
                    h, FoldIOTestSupport.dumpLines(loaded),
                    FoldIOTestSupport.parseLines(loadedLines[typeName]),
                    "\(name): \(typeName) load round-trip")
                let reExported = try OripaIO.exportCreasePattern(fileType, loaded)
                h.expectEqual(OripaIO.bytesToText(reExported),
                              FoldIOTestSupport.s(exports[typeName]),
                              "\(name): \(typeName) re-export byte-identical")
                h.expectEqual(FoldIOTestSupport.b(reexportIdentical[typeName]), true,
                              "\(name): \(typeName) fixture byte-identical marker")
                // external loads are marked modified
                h.expectEqual(loaded.modified, true, "\(name): \(typeName) load marks modified")
            }

            // filename dispatch + readCreasePatternFile + force loader keep working
            // CP export skips type-0 lines, so the loaded snapshot is the CP-format line set.
            let byName = try OripaIO.loadCreasePattern(data: OripaIO.exportCp(cp), filenameWithExt: "pattern.cp")
            FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(byName),
                                          FoldIOTestSupport.parseLines(loadedLines["cp"]),
                                          "\(name): loadCreasePattern(filenameWithExt:)")
            let byRead = try OripaIO.readCreasePatternFile(data: OripaIO.exportOpxc(cp), filename: "imported.opxc")
            FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(byRead), expectedLines,
                                          "\(name): readCreasePatternFile")
        }
    }

    // MARK: - force loader

    private static func forceLoad(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        let forceLoad = FoldIOTestSupport.dict(fixture["forceLoad"])
        let opxcText = FoldIOTestSupport.s(forceLoad["opxc"])
        let loaded = try OripaIO.loadCreasePatternForce(data: OripaIO.textToBytes(opxcText))
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(loaded),
                                      FoldIOTestSupport.parseLines(forceLoad["expectedLines"]),
                                      "force opxc")
        h.expectEqual(loaded.modified, false, "force load does not mark modified")

        let sniffed = try OripaIO.loadCreasePatternForce(data: OripaIO.textToBytes(FoldIOTestSupport.s(forceLoad["sniffedCp"])))
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(sniffed),
                                      FoldIOTestSupport.parseLines(forceLoad["sniffedExpectedLines"]),
                                      "force sniffed cp")
        // explicit type overload
        let explicit = try OripaIO.loadCreasePatternForce(data: OripaIO.textToBytes(opxcText), fileType: .opxc)
        h.expectEqual(FoldIOTestSupport.dumpLines(explicit).count,
                      FoldIOTestSupport.parseLines(forceLoad["expectedLines"]).count,
                      "force load with explicit type")
    }

    // MARK: - OPX tolerance

    private static func opxLoaderTolerance(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        let object = FoldIOTestSupport.dict(fixture["opxTolerate"])
        let xml = FoldIOTestSupport.s(object["xml"])
        let loaded = try OripaIO.loadCreasePattern(data: OripaIO.textToBytes(xml), filenameWithExt: "x.opx")
        let expected = FoldIOTestSupport.parseLines(object["expectedLines"])
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(loaded), expected, "opx tolerant load")
        h.expectEqual(expected.count, 1, "one tolerant OPX line")
        if let line = Array(loaded.lineMVFB).first {
            h.expectEqual(line.typeValue, 0, "missing type defaults to 0")
            h.expectClose(line.start.x, 0.0, accuracy: 0, "default x0")
            h.expectClose(line.start.y, -5.5, accuracy: 0, "y0 present")
            h.expectClose(line.end.x, 10.0, accuracy: 0, "x1 present")
            h.expectClose(line.end.y, 0.0, accuracy: 0, "default y1")
        }
    }

    // MARK: - malformed inputs

    private static func malformedInput(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        for entry in FoldIOTestSupport.array(fixture["malformed"]) {
            let object = FoldIOTestSupport.dict(entry)
            let typeName = FoldIOTestSupport.s(object["fileType"])
            let content = FoldIOTestSupport.s(object["content"])
            let marker = FoldIOTestSupport.s(object["marker"])
            var message = ""
            var threw = false
            do {
                if typeName == "xyz" {
                    _ = try OripaIO.loadCreasePattern(data: OripaIO.textToBytes(content), filenameWithExt: "bad.xyz")
                } else if let fileType = FileType.valueOf(typeName.uppercased()) {
                    _ = try OripaIO.loadCreasePattern(data: OripaIO.textToBytes(content), fileType: fileType)
                } else {
                    h.fail("unknown file type in malformed fixture: \(typeName)")
                    continue
                }
            } catch {
                threw = true
                message = String(describing: error)
            }
            h.expect(threw, "malformed \(typeName) input must throw")
            // JS asserts /Error/ generically; the Swift port keeps the Java exception names.
            let markerIsGenericError = marker == "Error"
            h.expect(markerIsGenericError || message.contains(marker),
                     "malformed \(typeName) error mentions \(marker): \(message)")
        }
    }

    // MARK: - LoaderOpxcToGL

    private static func loaderOpxcToGL(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/roundtrip.json")
        let object = FoldIOTestSupport.dict(fixture["loaderOpxcToGL"])
        let cp = buildCreasePatternSegmented()
        let bytes = OripaIO.exportOpxc(cp)
        var positions: [Float] = []
        var types: [Int] = []
        let minMax = MinMaxFloat()
        try LoaderOpxcToGL.getCreasePattern(bytes, &positions, &types, minMax)
        let expectedPositions = FoldIOTestSupport.array(object["positions"])
        if positions.count > 0, expectedPositions.count > 0,
           FoldIOTestSupport.d(positions[0]) != FoldIOTestSupport.d(expectedPositions[0]) {
            print("DEBUG opxc=\n" + OripaIO.bytesToText(bytes).prefix(300))
            print("DEBUG actual positions", positions.prefix(12), "expected", expectedPositions.prefix(12))
            print("DEBUG minmax actual", minMax.minX, minMax.minY, minMax.maxX, minMax.maxY)
        }
        FoldIOTestSupport.expectFloatArray(h, positions, expectedPositions,
                                           "LoaderOpxcToGL positions")
        FoldIOTestSupport.expectIntArray(h, types, FoldIOTestSupport.array(object["types"]),
                                         "LoaderOpxcToGL types")
        let fixtureMinMax = FoldIOTestSupport.dict(object["minMax"])
        h.expectClose(Double(minMax.minX), FoldIOTestSupport.d(fixtureMinMax["minX"]), accuracy: 1e-4, "minMax.minX")
        h.expectClose(Double(minMax.minY), FoldIOTestSupport.d(fixtureMinMax["minY"]), accuracy: 1e-4, "minMax.minY")
        h.expectClose(Double(minMax.maxX), FoldIOTestSupport.d(fixtureMinMax["maxX"]), accuracy: 1e-4, "minMax.maxX")
        h.expectClose(Double(minMax.maxY), FoldIOTestSupport.d(fixtureMinMax["maxY"]), accuracy: 1e-4, "minMax.maxY")
        h.expectEqual(positions.count, cp.lineMVFB.size() * 4, "4 floats per line")
        h.expectEqual(types.count, cp.lineMVFB.size() * 2, "2 type bytes per line")

        // empty file -> Java fallback viewport [-1,-1,1,1]
        var emptyPositions: [Float] = []
        var emptyTypes: [Int] = []
        let emptyMinMax = MinMaxFloat()
        try LoaderOpxcToGL.getCreasePattern(
            OripaIO.textToBytes("<data version=\"1.0\" paperSize=\"400\"></data>"),
            &emptyPositions, &emptyTypes, emptyMinMax)
        h.expectEqual(emptyPositions.count, 0, "empty opxc positions")
        h.expectEqual(emptyTypes.count, 0, "empty opxc types")
        h.expectEqual([emptyMinMax.minX, emptyMinMax.minY, emptyMinMax.maxX, emptyMinMax.maxY],
                      [-1.0, -1.0, 1.0, 1.0], "empty opxc fallback viewport")
        FoldIOTestSupport.expectIntArray(h, emptyTypes, FoldIOTestSupport.array(object["emptyTypes"]),
                                         "empty types fixture")
        h.expectEqual(FoldIOTestSupport.array(object["emptyPositions"]).count, 0, "empty positions fixture")
    }

    // MARK: - Exporter naming rules

    private static func exporterNaming(_ h: TestHarness) throws {
        var existing: Set<String> = []
        let exporter = Exporter(baseDir: "", fileExists: { existing.contains($0) })
        h.expectEqual(exporter.getNewInternalFile("project_data", "untitled"),
                      "project_data/untitled", "getNewInternalFile")
        h.expectEqual(exporter.getNewUniqueFile("project_data", "untitled"),
                      "project_data/untitled", "unique name (fresh)")
        existing.insert("project_data/untitled")
        h.expectEqual(exporter.getNewUniqueFile("project_data", "untitled"),
                      "project_data/untitled-1", "unique name -1")
        existing.insert("project_data/untitled-1")
        h.expectEqual(exporter.getNewUniqueFile("project_data", "untitled"),
                      "project_data/untitled-2", "unique name -2")
        h.expectEqual(exporter.getNewCopyFile("project_data", "untitled"),
                      "project_data/untitled-copy", "copy name")
        existing.insert("project_data/untitled-copy")
        h.expectEqual(exporter.getNewCopyFile("project_data", "untitled"),
                      "project_data/untitled-copy-copy", "copy name -copy-copy")
        h.expectEqual(exporter.getNewInternalFile("project_data"), "project_data", "getNewInternalFile dir only")
        h.expectEqual(exporter.getNewCopyInternalFile("project_data", "x"),
                      "project_data/x-copy", "getNewCopyInternalFile")
    }

    // MARK: - miscellaneous coverage

    private static func miscCoverage(_ h: TestHarness) throws {
        // FoldOverlapParams vertex-type constants (Java public static final byte).
        h.expectEqual(FoldOverlapParams.TYPE_FACE_FRONT, 0, "FoldOverlapParams.TYPE_FACE_FRONT")
        h.expectEqual(FoldOverlapParams.TYPE_FACE_BACK, 1, "FoldOverlapParams.TYPE_FACE_BACK")
        h.expectEqual(FoldOverlapParams.TYPE_LINE, 2, "FoldOverlapParams.TYPE_LINE")
        h.expectEqual(FoldOverlapParams.TYPE_SHADOW_INNER, 3, "FoldOverlapParams.TYPE_SHADOW_INNER")
        h.expectEqual(FoldOverlapParams.TYPE_SHADOW_OUTER, 4, "FoldOverlapParams.TYPE_SHADOW_OUTER")

        // FileUtil last-modified text helpers (locale-formatted, Android DateFormat replacement).
        h.expect(FileUtil.getLastModifiedText(1_700_000_000_000).isEmpty == false,
                 "getLastModifiedText returns text")
        h.expect(FileUtil.getLastModifiedTextShort(1_700_000_000_000).isEmpty == false,
                 "getLastModifiedTextShort returns text")

        // detectFileType content sniffing.
        h.expectEqual(OripaIO.detectFileType(OripaIO.textToBytes(
            "<?xml version='1.0'?><java class=\"java.beans.XMLDecoder\"></java>")),
                      FileType.opx, "detectFileType opx")
        h.expectEqual(OripaIO.detectFileType(OripaIO.textToBytes("<data><line/></data>")),
                      FileType.opxc, "detectFileType opxc")
        h.expectEqual(OripaIO.detectFileType(OripaIO.textToBytes("1 0 0 1 1")),
                      FileType.cp, "detectFileType cp")

        // PNG export is owned by the UI layer: the IO facade rejects it.
        var pngError = ""
        do {
            _ = try OripaIO.exportCreasePattern(.png, CreasePattern())
        } catch {
            pngError = String(describing: error)
        }
        h.expect(pngError.contains("PNG"), "exportCreasePattern(.png) throws a clear error: \(pngError)")

        // Every text format agrees on the line set (no flat lines in this CP).
        let cp = buildCreasePatternSegmented()
        let viaOpx = try OripaIO.loadCreasePattern(data: OripaIO.exportOpx(cp), fileType: .opx)
        let viaOpxc = try OripaIO.loadCreasePattern(data: OripaIO.exportOpxc(cp), fileType: .opxc)
        let viaCp = try OripaIO.loadCreasePattern(data: OripaIO.exportCp(cp), fileType: .cp)
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(viaOpx),
                                      FoldIOTestSupport.dumpLines(cp), "opx vs source")
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(viaOpxc),
                                      FoldIOTestSupport.dumpLines(cp), "opxc vs source")
        FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(viaCp),
                                      FoldIOTestSupport.dumpLines(cp), "cp vs source")

        // UTF-8 byte/text helpers round-trip (Java String <-> byte[]).
        let text = "line type 2: -200.0 0.5 é"
        h.expectEqual(OripaIO.bytesToText(OripaIO.textToBytes(text)), text, "textToBytes/bytesToText")
        h.expectEqual(OripaIO.bytesToText(Data([0x61, 0x62])), "ab", "bytesToText ascii")
    }

    // MARK: - CP builders (mirror the JS generator exactly)

    static func buildCreasePatternSegmented() -> CreasePattern {
        let cp = CreasePattern()
        let half = Double(cp.creasePatternHalfSize)
        let corners: [[Double]] = [
            [-half, -half], [0, -half], [half, -half],
            [half, half], [0, half], [-half, half],
        ]
        for index in 0..<corners.count {
            let a = corners[index]
            let b = corners[(index + 1) % corners.count]
            cp.addLineCheckNoException(OriLine(OriPoint(a[0], a[1]), OriPoint(b[0], b[1]), LineType.boundary))
        }
        cp.addLineCheckNoException(OriLine(OriPoint(0, -half), OriPoint(0, half), LineType.valley))
        return cp
    }

    static func buildCreasePatternMixed() -> CreasePattern {
        let cp = CreasePattern()
        cp.initializeDefaultSquare()
        cp.addLineCheckNoException(OriLine(OriPoint(-200, -200), OriPoint(200, 200), LineType.mountain))
        cp.addLineCheckNoException(OriLine(OriPoint(-100, 0), OriPoint(100, 0), LineType.flat))
        cp.addLineCheckNoException(OriLine(OriPoint(-50, 50), OriPoint(50, 50), LineType.grid))
        cp.addLineCheckNoException(OriLine(OriPoint(0, 0), OriPoint(0.0015, 0.0015), LineType.mountain))
        cp.addLineCheckNoException(OriLine(OriPoint(0, 0), OriPoint(400, -400), LineType.valley))
        return cp
    }

    static func buildCreasePatternSmall() -> CreasePattern {
        let cp = CreasePattern()
        cp.addLineCheckNoException(OriLine(OriPoint(-10.5, 0.25), OriPoint(10.5, -0.25), LineType.mountain))
        cp.addLineCheckNoException(OriLine(OriPoint(0, -10), OriPoint(0, 10), LineType.valley))
        return cp
    }
}

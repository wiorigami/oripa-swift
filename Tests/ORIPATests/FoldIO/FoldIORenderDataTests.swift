// fold-io render-data golden tests (port of oripa-port/tools/tests/test_render_renderdata.js
// coverage for the GLData* builders owned by fold-io).
//
// Fixtures/foldio/renderdata.json holds every GLData* output for two crease patterns,
// generated from the reference JavaScript implementation.
import Foundation
import ORIPACore

enum FoldIORenderDataTests {
    static var all: [TestSuite] {
        [
            TestSuite("FoldIO.RenderData.builders") { h in try builders(h) },
            TestSuite("FoldIO.RenderData.crossLine") { h in try crossLine(h) },
            TestSuite("FoldIO.RenderData.foldOverlap") { h in try foldOverlap(h) },
            TestSuite("FoldIO.RenderData.foldXrayCross") { h in try foldXrayCross(h) },
        ]
    }

    // MARK: - CP builders

    private static func builders(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/renderdata.json")
        let cases = FoldIOTestSupport.array(fixture["cps"])
        h.expectEqual(cases.count, 2, "two render-data CP cases")
        for entry in cases {
            let object = FoldIOTestSupport.dict(entry)
            let name = FoldIOTestSupport.s(object["name"])
            let cp: CreasePattern
            if name == "segmentedSquare" {
                cp = FoldIOIOTests.buildCreasePatternSegmented()
            } else {
                cp = try FoldIOTestSupport.loadCase("fold_in_half.cp")
            }
            let lines = FoldIOTestSupport.parseLines(object["lines"])
            FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(cp), lines, "\(name): lines")
            h.expectEqual(cp.lineMVFB.size(), FoldIOTestSupport.i(object["lineCount"]), "\(name): line count")
            h.expectEqual(cp.points.count, FoldIOTestSupport.i(object["pointCount"]), "\(name): point count")
            h.expectEqual(cp.isFlatFoldable(), FoldIOTestSupport.b(object["flatFoldable"]),
                          "\(name): isFlatFoldable")

            // --- GLDataCpLinesTyped
            let typed = FoldIOTestSupport.dict(object["typed"])
            for (key, lineFilter) in [("all", (false, false)), ("mvb", (true, false)),
                                      ("flatOnly", (false, true)), ("both", (true, true))] {
                let expected = FoldIOTestSupport.dict(typed[key])
                let data = GLDataCpLinesTyped.getRenderData(Array(cp.lineMVFB), lineFilter.0, lineFilter.1)
                FoldIOTestSupport.expectFloatArray(h, data.lineArray,
                                                   FoldIOTestSupport.array(expected["lineArray"]),
                                                   "\(name): typed.\(key).lineArray")
                FoldIOTestSupport.expectByteArray(h, data.typeArray,
                                                  FoldIOTestSupport.array(expected["typeArray"]),
                                                  "\(name): typed.\(key).typeArray")
            }

            // --- GLDataCpLinesTypedWidth
            let typedWidth = FoldIOTestSupport.dict(object["typedWidth"])
            for (key, lineFilter) in [("all", (true, true)), ("mvb", (true, false)), ("flatOnly", (false, true))] {
                let expectedSets = FoldIOTestSupport.array(typedWidth[key])
                let actualSets = GLDataCpLinesTypedWidth.getRenderDataSplit(Array(cp.lineMVFB), lineFilter.0, lineFilter.1)
                h.expectEqual(actualSets.count, expectedSets.count, "\(name): typedWidth.\(key) set count")
                for (setIndex, expectedSet) in expectedSets.enumerated() where setIndex < actualSets.count {
                    let set = actualSets[setIndex]
                    let expected = FoldIOTestSupport.dict(expectedSet)
                    let label = "\(name): typedWidth.\(key)[\(setIndex)]"
                    FoldIOTestSupport.expectFloatArray(h, set.vertexPosition,
                                                       FoldIOTestSupport.array(expected["vertexPosition"]),
                                                       "\(label).vertexPosition")
                    FoldIOTestSupport.expectFloatArray(h, set.vertexAngleDeg,
                                                       FoldIOTestSupport.array(expected["vertexAngleDeg"]),
                                                       "\(label).vertexAngleDeg")
                    FoldIOTestSupport.expectFloatArray(h, set.lineDistance,
                                                       FoldIOTestSupport.array(expected["lineDistance"]),
                                                       "\(label).lineDistance")
                    FoldIOTestSupport.expectByteArray(h, set.vertexType,
                                                      FoldIOTestSupport.array(expected["vertexType"]),
                                                      "\(label).vertexType")
                    FoldIOTestSupport.expectIntArray(h, set.drawOrder,
                                                     FoldIOTestSupport.array(expected["drawOrder"]),
                                                     "\(label).drawOrder")
                }
            }

            // --- GLDataLinesWidth
            let linesWidth = FoldIOTestSupport.dict(object["linesWidth"])
            let expectedAll = FoldIOTestSupport.dict(linesWidth["all"])
            let actualAll = GLDataLinesWidth.getRenderData(Array(cp.lineMVFB))
            FoldIOTestSupport.expectFloatArray(h, actualAll.vertexPosition,
                                               FoldIOTestSupport.array(expectedAll["vertexPosition"]),
                                               "\(name): linesWidth.all.vertexPosition")
            FoldIOTestSupport.expectFloatArray(h, actualAll.vertexAngleDeg,
                                               FoldIOTestSupport.array(expectedAll["vertexAngleDeg"]),
                                               "\(name): linesWidth.all.vertexAngleDeg")
            FoldIOTestSupport.expectIntArray(h, actualAll.drawOrder,
                                             FoldIOTestSupport.array(expectedAll["drawOrder"]),
                                             "\(name): linesWidth.all.drawOrder")
            let expectedSingle = FoldIOTestSupport.dict(linesWidth["single"])
            let actualSingle = GLDataLinesWidth.getRenderData(Array(cp.lineMVFB).first)
            FoldIOTestSupport.expectFloatArray(h, actualSingle.vertexPosition,
                                               FoldIOTestSupport.array(expectedSingle["vertexPosition"]),
                                               "\(name): linesWidth.single.vertexPosition")
            FoldIOTestSupport.expectIntArray(h, actualSingle.drawOrder,
                                             FoldIOTestSupport.array(expectedSingle["drawOrder"]),
                                             "\(name): linesWidth.single.drawOrder")
            let expectedSplit = FoldIOTestSupport.array(linesWidth["split"])
            let actualSplit = GLDataLinesWidth.getRenderDataSplit(Array(cp.lineMVFB))
            h.expectEqual(actualSplit.count, expectedSplit.count, "\(name): linesWidth split set count")
            for (index, expectedSet) in expectedSplit.enumerated() where index < actualSplit.count {
                let set = actualSplit[index]
                let expected = FoldIOTestSupport.dict(expectedSet)
                FoldIOTestSupport.expectFloatArray(h, set.vertexPosition,
                                                   FoldIOTestSupport.array(expected["vertexPosition"]),
                                                   "\(name): linesWidth.split[\(index)].vertexPosition")
                FoldIOTestSupport.expectIntArray(h, set.drawOrder,
                                                 FoldIOTestSupport.array(expected["drawOrder"]),
                                                 "\(name): linesWidth.split[\(index)].drawOrder")
            }

            // --- GLDataCpPolygons
            let polygons = FoldIOTestSupport.dict(object["polygons"])
            let polygonData = GLDataCpPolygons.getRenderData(cp.facesCheck)
            FoldIOTestSupport.expectFloatArray(h, polygonData.pointArray,
                                               FoldIOTestSupport.array(polygons["pointArray"]),
                                               "\(name): polygons.pointArray")
            FoldIOTestSupport.expectIntArray(h, polygonData.drawOrderArray,
                                             FoldIOTestSupport.array(polygons["drawOrderArray"]),
                                             "\(name): polygons.drawOrderArray")

            // --- GLDataCpSimple
            let simple = FoldIOTestSupport.dict(object["simple"])
            FoldIOTestSupport.expectFloatArray(h, GLDataCpSimple.linesToFloats(Array(cp.lineMVFB)),
                                               FoldIOTestSupport.array(simple["linesToFloats"]),
                                               "\(name): simple.linesToFloats")
            FoldIOTestSupport.expectFloatArray(h, GLDataCpSimple.pointsToFloatsSimple(cp.points),
                                               FoldIOTestSupport.array(simple["pointsToFloatsSimple"]),
                                               "\(name): simple.pointsToFloatsSimple")
            FoldIOTestSupport.expectFloatArray(h, GLDataCpSimple.pointsToFloats(cp.points, true, true),
                                               FoldIOTestSupport.array(simple["pointsFilteredBoth"]),
                                               "\(name): simple.pointsFilteredBoth")
            FoldIOTestSupport.expectFloatArray(h, GLDataCpSimple.pointsToFloats(cp.points, false, false),
                                               FoldIOTestSupport.array(simple["pointsFilteredNone"]),
                                               "\(name): simple.pointsFilteredNone")

            // --- GLDataCpPreview (from the OPXC bytes)
            let preview = FoldIOTestSupport.dict(object["preview"])
            let previewData = try GLDataCpPreview.getRenderData(OripaIO.exportOpxc(cp))
            FoldIOTestSupport.expectFloatArray(h, previewData.linePosition,
                                               FoldIOTestSupport.array(preview["linePosition"]),
                                               "\(name): preview.linePosition")
            FoldIOTestSupport.expectIntArray(h, previewData.lineType,
                                             FoldIOTestSupport.array(preview["lineType"]),
                                             "\(name): preview.lineType")
            let previewMinMax = FoldIOTestSupport.dict(preview["minMax"])
            h.expectClose(Double(previewData.minMax.minX), FoldIOTestSupport.d(previewMinMax["minX"]),
                          "\(name): preview.minX")
            h.expectClose(Double(previewData.minMax.minY), FoldIOTestSupport.d(previewMinMax["minY"]),
                          "\(name): preview.minY")
            h.expectClose(Double(previewData.minMax.maxX), FoldIOTestSupport.d(previewMinMax["maxX"]),
                          "\(name): preview.maxX")
            h.expectClose(Double(previewData.minMax.maxY), FoldIOTestSupport.d(previewMinMax["maxY"]),
                          "\(name): preview.maxY")

            let blank = FoldIOTestSupport.dict(preview["blank"])
            let blankData = GLDataCpPreview.getRenderDataBlank()
            h.expectEqual(blankData.linePosition.count, 0, "\(name): blank preview positions")
            h.expectEqual(blankData.lineType.count, 0, "\(name): blank preview types")
            let blankMinMax = FoldIOTestSupport.dict(blank["minMax"])
            h.expectEqual([blankData.minMax.minX, blankData.minMax.minY, blankData.minMax.maxX, blankData.minMax.maxY],
                          [Float(FoldIOTestSupport.d(blankMinMax["minX"])), Float(FoldIOTestSupport.d(blankMinMax["minY"])),
                           Float(FoldIOTestSupport.d(blankMinMax["maxX"])), Float(FoldIOTestSupport.d(blankMinMax["maxY"]))],
                          "\(name): blank preview minMax")
        }
    }

    // MARK: - CrossLine geometry (engine.json)

    private static func crossLine(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/engine.json")
        let crossLineFixture = FoldIOTestSupport.dict(fixture["crossLine"])
        let half200 = FoldIOTestSupport.dict(crossLineFixture["halfSize200"])
        let crossLine = CrossLine(200)
        h.expectEqual(crossLine.getAngleDegDefaultMagnitude(),
                      FoldIOTestSupport.i(half200["angleDegDefault"]), "angleDegDefault")
        h.expectEqual(crossLine.getAngleDegMaxMagnitude(),
                      FoldIOTestSupport.i(half200["angleDegMax"]), "angleDegMax")
        h.expectEqual(crossLine.getPositionMinMagnitude(),
                      FoldIOTestSupport.i(half200["positionMin"]), "positionMin")
        h.expectEqual(crossLine.getPositionMaxMagnitude(),
                      FoldIOTestSupport.i(half200["positionMax"]), "positionMax")
        h.expectEqual(crossLine.getPositionDefaultMagnitude(),
                      FoldIOTestSupport.i(half200["positionDefault"]), "positionDefault")
        h.expectClose(crossLine.getCrossLineHalfLength(),
                      FoldIOTestSupport.d(half200["getCrossLineHalfLength"]), "crossLineHalfLength")

        let half50 = FoldIOTestSupport.dict(crossLineFixture["halfSize50"])
        let crossLine50 = CrossLine(50)
        h.expectEqual(crossLine50.getPositionDefaultMagnitude(),
                      FoldIOTestSupport.i(half50["positionDefault"]), "halfSize50 positionDefault")
        h.expectEqual(crossLine50.getPositionMaxMagnitude(),
                      FoldIOTestSupport.i(half50["positionMax"]), "halfSize50 positionMax")
        h.expectClose(crossLine50.getCrossLineHalfLength(),
                      FoldIOTestSupport.d(half50["getCrossLineHalfLength"]), "halfSize50 halfLength")

        for entry in FoldIOTestSupport.array(crossLineFixture["segments"]) {
            let object = FoldIOTestSupport.dict(entry)
            let angle = FoldIOTestSupport.i(object["angleDeg"])
            let position = FoldIOTestSupport.i(object["position"])
            let segment = crossLine.getFmCrossLine(angleDeg: angle, position: position)
            let expectedStart = FoldIOTestSupport.parsePoint(object["start"])
            let expectedEnd = FoldIOTestSupport.parsePoint(object["end"])
            h.expectClose(segment.start.x, expectedStart.x, accuracy: 1e-9,
                          "getFmCrossLine(\(angle),\(position)).start.x")
            h.expectClose(segment.start.y, expectedStart.y, accuracy: 1e-9,
                          "getFmCrossLine(\(angle),\(position)).start.y")
            h.expectClose(segment.end.x, expectedEnd.x, accuracy: 1e-9,
                          "getFmCrossLine(\(angle),\(position)).end.x")
            h.expectClose(segment.end.y, expectedEnd.y, accuracy: 1e-9,
                          "getFmCrossLine(\(angle),\(position)).end.y")
        }
    }

    // MARK: - GLDataFmOverlap

    private static func foldOverlap(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/engine.json")
        let models = FoldIOTestSupport.array(fixture["models"])
        for entry in models {
            let object = FoldIOTestSupport.dict(entry)
            let name = FoldIOTestSupport.s(object["name"])
            guard let folded = object["folded"] as? [String: Any],
                  FoldIOTestSupport.i(folded["faces"]) > 0,
                  let renderData = object["renderData"] as? [String: Any] else {
                continue
            }
            let model = try FoldIOTestSupport.buildFoldedModel(object)
            let expectedNoShadow = FoldIOTestSupport.array(renderData["overlapSplitNoShadow"])
            let actualNoShadow = GLDataFmOverlap.getRenderDataSplit(
                model.sortedFaces, model.sortedFacesReverse, false)
            h.expectEqual(actualNoShadow.count, expectedNoShadow.count, "\(name): overlap split count")
            for (index, expectedEntry) in expectedNoShadow.enumerated() where index < actualNoShadow.count {
                FoldIOTestSupport.expectOverlap(h, actualNoShadow[index],
                                                FoldIOTestSupport.dict(expectedEntry),
                                                "\(name): overlap.noShadow[\(index)]")
            }
            let expectedShadow = FoldIOTestSupport.array(renderData["overlapSplitWithShadow"])
            let actualShadow = GLDataFmOverlap.getRenderDataSplit(
                model.sortedFaces, model.sortedFacesReverse, true)
            h.expectEqual(actualShadow.count, expectedShadow.count, "\(name): overlap shadow split count")
            for (index, expectedEntry) in expectedShadow.enumerated() where index < actualShadow.count {
                FoldIOTestSupport.expectOverlap(h, actualShadow[index],
                                                FoldIOTestSupport.dict(expectedEntry),
                                                "\(name): overlap.withShadow[\(index)]")
            }
        }
        // blank split
        let blank = GLDataFmOverlap.getRenderDataBlankSplit()
        h.expectEqual(blank.count, 6, "blank overlap split has 6 sets")
        for set in blank {
            h.expectEqual(set.pointPosition.count, 0, "blank overlap front positions empty")
            h.expectEqual(set.reversePointPosition.count, 0, "blank overlap reverse positions empty")
            h.expectEqual(set.drawOrder.count, 0, "blank overlap draw order empty")
        }
    }

    // MARK: - GLDataFmXrayCross

    private static func foldXrayCross(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/engine.json")
        for entry in FoldIOTestSupport.array(fixture["models"]) {
            let object = FoldIOTestSupport.dict(entry)
            let name = FoldIOTestSupport.s(object["name"])
            guard let renderData = object["renderData"] as? [String: Any] else { continue }
            let expected = FoldIOTestSupport.dict(renderData["xray"])
            let model = try FoldIOTestSupport.buildFoldedModel(object)
            let data = GLDataFmXrayCross.getRenderData(model.mVertices, model.mHalfEdges, model.mFaces)
            FoldIOTestSupport.expectFloatArray(h, data.cpPointPosition,
                                               FoldIOTestSupport.array(expected["cpPointPosition"]),
                                               "\(name): xray.cpPointPosition")
            FoldIOTestSupport.expectByteArray(h, data.cpLineType,
                                              FoldIOTestSupport.array(expected["cpLineType"]),
                                              "\(name): xray.cpLineType")
            FoldIOTestSupport.expectIntArray(h, data.cpLineDrawOrder,
                                             FoldIOTestSupport.array(expected["cpLineDrawOrder"]),
                                             "\(name): xray.cpLineDrawOrder")
            FoldIOTestSupport.expectIntArray(h, data.cpPolygonDrawOrder,
                                             FoldIOTestSupport.array(expected["cpPolygonDrawOrder"]),
                                             "\(name): xray.cpPolygonDrawOrder")
            FoldIOTestSupport.expectFloatArray(h, data.fmPointPosition,
                                               FoldIOTestSupport.array(expected["fmPointPosition"]),
                                               "\(name): xray.fmPointPosition")
            FoldIOTestSupport.expectIntArray(h, data.fmFaceDrawOrder,
                                             FoldIOTestSupport.array(expected["fmFaceDrawOrder"]),
                                             "\(name): xray.fmFaceDrawOrder")
            FoldIOTestSupport.expectIntArray(h, data.fmBoundaryLineDrawOrder,
                                             FoldIOTestSupport.array(expected["fmBoundaryLineDrawOrder"]),
                                             "\(name): xray.fmBoundaryLineDrawOrder")
            FoldIOTestSupport.expectIntArray(h, data.fmCreaseLineDrawOrder,
                                             FoldIOTestSupport.array(expected["fmCreaseLineDrawOrder"]),
                                             "\(name): xray.fmCreaseLineDrawOrder")

            // cut-line render data (CrossLineManager.getNew defaults)
            let expectedManager = FoldIOTestSupport.dict(FoldIOTestSupport.dict(renderData["crossLineManager"])["afterGetNew"])
            let manager = CrossLineManager()
            manager.getNew(model)
            h.expectEqual(manager.getCurrentCrossLineAngleDeg(),
                          FoldIOTestSupport.i(expectedManager["angleDeg"]), "\(name): cross line angle")
            h.expectEqual(manager.getCurrentCrossLinePosition(),
                          FoldIOTestSupport.i(expectedManager["position"]), "\(name): cross line position")
            if let data = manager.getCrossLineRenderData() {
                FoldIOTestSupport.expectFloatArray(h, data.fmPosition,
                                                   FoldIOTestSupport.array(expectedManager["fmPosition"]),
                                                   "\(name): cross line fmPosition")
                FoldIOTestSupport.expectFloatArray(h, data.cpPosition,
                                                   FoldIOTestSupport.array(expectedManager["cpPosition"]),
                                                   "\(name): cross line cpPosition")
            } else {
                h.fail("\(name): CrossLineManager.getNew returned no render data")
            }
            let expectedUpdate = FoldIOTestSupport.dict(FoldIOTestSupport.dict(renderData["crossLineManager"])["afterUpdate"])
            manager.updateCrossLineRenderData(model, angleDeg: 90, position: 150)
            h.expectEqual(manager.getCurrentCrossLineAngleDeg(), 90, "\(name): updated cross line angle")
            h.expectEqual(manager.getCurrentCrossLinePosition(), 150, "\(name): updated cross line position")
            if let data = manager.getCrossLineRenderData() {
                FoldIOTestSupport.expectFloatArray(h, data.cpPosition,
                                                   FoldIOTestSupport.array(expectedUpdate["cpPosition"]),
                                                   "\(name): updated cross line cpPosition")
            }
        }
    }
}

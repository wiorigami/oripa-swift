// fold-io oracle-case golden tests (port of oripa-port/tools/tests/test_fold_oracle_cases.js).
//
// Runs the full stack (my loaders + core-model CreasePattern/isFlatFoldable + fold-engine
// FoldedModel + my exporters/render data) against the six certified fixtures in
// Fixtures/cases/** and compares every observable output with the reference JS
// implementation (Fixtures/foldio/cases.json).
//
// Tolerances: counts/indices/types/face flags exact; CP coordinates exact; folded-model
// geometry (valueAfterFold, transformMatrix) 1e-4 absolute (Java float encodings vs the JS
// reference's doubles); the cut-line invariant must stay below 1e-3 like the JS suite.
import Foundation
import ORIPACore

enum FoldIOOracleTests {
    private static let matrixTolerance = 1e-3

    static var all: [TestSuite] {
        [
            TestSuite("FoldIO.Oracle.cases") { h in try cases(h) },
            TestSuite("FoldIO.Oracle.robustness") { h in try robustness(h) },
        ]
    }

    // MARK: - helpers

    private static func foldedModelMaxMatrixError(_ model: FoldedModel) -> Double {
        var maxError = 0.0
        for face in model.mFaces {
            for halfEdge in face.halfEdges {
                let transformed = GLUtil.getTransformedPointDouble(
                    face.transformMatrix, Float(halfEdge.start.x), Float(halfEdge.start.y))
                guard let folded = halfEdge.start.valueAfterFold else { continue }
                maxError = max(maxError, abs(transformed.x - folded.x), abs(transformed.y - folded.y))
            }
        }
        return maxError
    }

    /// Fold-audit "inconsistent face" metric: a face whose transform matrix does not map its
    /// CP vertices onto their valueAfterFold positions (the regression the missing-`continue`
    /// fold-walk bug produced; the reference reports 0 for every flat-foldable fixture).
    private static func inconsistentFaceCount(_ model: FoldedModel) -> Int {
        var count = 0
        for face in model.mFaces {
            var inconsistent = false
            for halfEdge in face.halfEdges {
                guard let folded = halfEdge.start.valueAfterFold else {
                    inconsistent = true
                    break
                }
                let transformed = GLUtil.getTransformedPointDouble(
                    face.transformMatrix, Float(halfEdge.start.x), Float(halfEdge.start.y))
                if hypot(transformed.x - folded.x, transformed.y - folded.y) >= matrixTolerance {
                    inconsistent = true
                    break
                }
            }
            if inconsistent { count += 1 }
        }
        return count
    }

    private static func fold(_ cp: CreasePattern, halfSize: Double = 200.0) -> FoldedModel {
        let model = FoldedModel(foldedModelHalfSize: halfSize)
        model.foldWithoutOverlap(cp)
        model.foldWithOverlap()
        return model
    }

    private static func sortedErrorPoints(_ cp: CreasePattern) -> [FoldIOTestSupport.Pt] {
        cp.pointErrorCheck
            .map { FoldIOTestSupport.Pt(x: $0.x, y: $0.y) }
            .sorted { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) }
    }

    private static func expectedErrorPoints(_ array: [Any]) -> [FoldIOTestSupport.Pt] {
        array.map { FoldIOTestSupport.parsePoint($0) }
    }

    // MARK: - main suite

    private static func cases(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/cases.json")
        let caseList = FoldIOTestSupport.array(fixture["cases"])
        h.expectEqual(caseList.count, 6, "six oracle case files")

        for entry in caseList {
            let object = FoldIOTestSupport.dict(entry)
            let name = FoldIOTestSupport.s(object["name"])
            let cp = try FoldIOTestSupport.loadCase(name)

            // Input snapshot: the line tree iteration order + coordinates must match the JS.
            FoldIOTestSupport.expectLines(h, FoldIOTestSupport.dumpLines(cp),
                                          FoldIOTestSupport.parseLines(object["lines"]),
                                          "\(name): loaded lines")
            h.expectEqual(cp.lineMVFB.size(), FoldIOTestSupport.i(object["lineCount"]), "\(name): line count")
            h.expectEqual(cp.creasePatternHalfSize, Float(FoldIOTestSupport.d(object["cpHalfSize"])),
                          "\(name): creasePatternHalfSize")

            // Flat-foldability verdict + error data (the fold engine consumes facesCheck).
            let flat = cp.isFlatFoldable()
            h.expectEqual(flat, FoldIOTestSupport.b(object["flatFoldable"]), "\(name): isFlatFoldable")
            h.expectEqual(cp.facesCheck.count, FoldIOTestSupport.i(object["facesCheckCount"]),
                          "\(name): facesCheck count")
            h.expectEqual(cp.pointErrorCheck.count, FoldIOTestSupport.i(object["pointErrorCount"]),
                          "\(name): pointErrorCheck count")
            let errorPoints = sortedErrorPoints(cp)
            let expectedErrors = expectedErrorPoints(FoldIOTestSupport.array(object["errorPoints"]))
            h.expectEqual(errorPoints.count, expectedErrors.count, "\(name): error point count")
            for index in 0..<min(errorPoints.count, expectedErrors.count) {
                h.expectClose(errorPoints[index].x, expectedErrors[index].x, accuracy: 1e-9,
                              "\(name): error[\(index)].x")
                h.expectClose(errorPoints[index].y, expectedErrors[index].y, accuracy: 1e-9,
                              "\(name): error[\(index)].y")
            }
            guard flat else { continue }

            // Fold both stages.
            let model = fold(cp)
            guard let folded = object["folded"] as? [String: Any] else {
                h.fail("\(name): fixture has no folded data for a flat-foldable case")
                continue
            }
            h.expectEqual(model.mFaces.count, FoldIOTestSupport.i(folded["faces"]), "\(name): folded faces")
            h.expectEqual(model.mVertices.count, FoldIOTestSupport.i(folded["vertices"]),
                          "\(name): folded vertices")
            h.expectEqual(model.mHalfEdges.count, FoldIOTestSupport.i(folded["halfEdges"]),
                          "\(name): folded half edges")
            h.expectEqual(model.componentCount, FoldIOTestSupport.i(folded["componentCount"]),
                          "\(name): fold walk componentCount (missing-continue regression)")
            h.expectClose(model.foldedModelHalfSize,
                          FoldIOTestSupport.d(folded["foldedModelHalfSize"]), accuracy: 0,
                          "\(name): foldedModelHalfSize")

            // Per-vertex CP coordinates + valueAfterFold.
            let vertexData = FoldIOTestSupport.array(folded["vertexData"])
            h.expectEqual(model.mVertices.count, vertexData.count, "\(name): vertexData count")
            for (index, vertexEntry) in vertexData.enumerated() where index < model.mVertices.count {
                let expected = FoldIOTestSupport.dict(vertexEntry)
                let vertex = model.mVertices[index]
                h.expectEqual(vertex.index, FoldIOTestSupport.i(expected["index"]), "\(name): vertex[\(index)].index")
                h.expectClose(vertex.x, FoldIOTestSupport.d(expected["x"]), accuracy: 1e-9,
                              "\(name): vertex[\(index)].x")
                h.expectClose(vertex.y, FoldIOTestSupport.d(expected["y"]), accuracy: 1e-9,
                              "\(name): vertex[\(index)].y")
                guard let value = vertex.valueAfterFold else {
                    h.fail("\(name): vertex[\(index)] has no valueAfterFold")
                    continue
                }
                h.expectClose(value.x, FoldIOTestSupport.d(expected["foldedX"]), accuracy: 1e-4,
                              "\(name): vertex[\(index)].foldedX")
                h.expectClose(value.y, FoldIOTestSupport.d(expected["foldedY"]), accuracy: 1e-4,
                              "\(name): vertex[\(index)].foldedY")
            }

            // Per-face orientation, transform matrix, half-edge wiring.
            let faceData = FoldIOTestSupport.array(folded["faceData"])
            h.expectEqual(model.mFaces.count, faceData.count, "\(name): faceData count")
            for (faceIndex, faceEntry) in faceData.enumerated() where faceIndex < model.mFaces.count {
                let expected = FoldIOTestSupport.dict(faceEntry)
                let face = model.mFaces[faceIndex]
                h.expectEqual(face.index, FoldIOTestSupport.i(expected["index"]), "\(name): face[\(faceIndex)].index")
                h.expectEqual(face.isCCWOrientation, FoldIOTestSupport.b(expected["isCCW"]),
                              "\(name): face[\(faceIndex)].isCCWOrientation")
                let expectedMatrix = FoldIOTestSupport.doubles(expected["matrix"])
                h.expectEqual(face.transformMatrix.count, 16, "\(name): face[\(faceIndex)].matrix size")
                for element in 0..<min(16, expectedMatrix.count) {
                    h.expectClose(Double(face.transformMatrix[element]), expectedMatrix[element],
                                  accuracy: 1e-4, "\(name): face[\(faceIndex)].matrix[\(element)]")
                }
                let halfEdges = FoldIOTestSupport.array(expected["halfEdges"])
                h.expectEqual(face.halfEdges.count, halfEdges.count, "\(name): face[\(faceIndex)].halfEdges count")
                for (edgeIndex, edgeEntry) in halfEdges.enumerated() where edgeIndex < face.halfEdges.count {
                    let expectedEdge = FoldIOTestSupport.dict(edgeEntry)
                    let halfEdge = face.halfEdges[edgeIndex]
                    h.expectEqual(halfEdge.start.index, FoldIOTestSupport.i(expectedEdge["start"]),
                                  "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].start")
                    h.expectEqual(halfEdge.end.index, FoldIOTestSupport.i(expectedEdge["end"]),
                                  "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].end")
                    h.expectEqual(halfEdge.lineType, FoldIOTestSupport.i(expectedEdge["lineType"]),
                                  "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].lineType")
                    let expectedTwinStart = FoldIOTestSupport.i(expectedEdge["twinStart"])
                    let expectedTwinEnd = FoldIOTestSupport.i(expectedEdge["twinEnd"])
                    if expectedTwinStart < 0 {
                        h.expectNil(halfEdge.twin, "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].twin")
                    } else {
                        h.expectEqual(halfEdge.twin?.start.index, expectedTwinStart,
                                      "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].twinStart")
                        h.expectEqual(halfEdge.twin?.end.index, expectedTwinEnd,
                                      "\(name): face[\(faceIndex)].halfEdge[\(edgeIndex)].twinEnd")
                    }
                }
            }

            // Draw orders (overlap view). The reference JS is deterministic; sizes and every
            // face index are compared.
            FoldIOTestSupport.expectIntArray(h, model.sortedFaces.map { $0.index },
                                             FoldIOTestSupport.array(folded["sortedFaces"]),
                                             "\(name): sortedFaces")
            FoldIOTestSupport.expectIntArray(h, model.sortedFacesReverse.map { $0.index },
                                             FoldIOTestSupport.array(folded["sortedFacesReverse"]),
                                             "\(name): sortedFacesReverse")
            h.expectEqual(Set(model.sortedFaces.map { $0.index }).count, model.mFaces.count,
                          "\(name): sortedFaces covers every face once")
            h.expectEqual(Set(model.sortedFacesReverse.map { $0.index }).count, model.mFaces.count,
                          "\(name): sortedFacesReverse covers every face once")

            // Cut-line invariant (the direct regression for the fold-walk bug).
            let matrixError = foldedModelMaxMatrixError(model)
            h.expect(matrixError < matrixTolerance,
                     "\(name): face matrix vs valueAfterFold max error \(matrixError) >= \(matrixTolerance)")
            let expectedMatrixError = FoldIOTestSupport.d(folded["maxMatrixError"])
            h.expect(matrixError <= expectedMatrixError + matrixTolerance,
                     "\(name): matrix error \(matrixError) far above reference \(expectedMatrixError)")
            let inconsistent = inconsistentFaceCount(model)
            h.expectEqual(inconsistent, 0, "\(name): inconsistently placed faces (\(inconsistent))")

            // Folded model fits the configured half size.
            var inside = true
            for vertex in model.mVertices {
                guard let value = vertex.valueAfterFold else { continue }
                if abs(value.x) > model.foldedModelHalfSize + matrixTolerance ||
                    abs(value.y) > model.foldedModelHalfSize + matrixTolerance {
                    inside = false
                }
            }
            h.expect(inside, "\(name): folded model fits inside ±\(model.foldedModelHalfSize)")

            // SVG exports (overlap / overlap-flipped / xray / wireframe).
            guard let svg = object["svg"] as? [String: Any] else {
                h.fail("\(name): fixture has no svg section")
                continue
            }
            let overlapSvg = OripaIO.exportFoldedModelSvg(model, mode: 1)
            FoldIOTestSupport.expectSvg(h, overlapSvg, FoldIOTestSupport.s(svg["overlap"]),
                                        "\(name): overlap svg")
            let flipSvg = OripaIO.exportFoldedModelSvg(
                model, mode: 1,
                options: FoldedModelSvgOptions(flip: true))
            FoldIOTestSupport.expectSvg(h, flipSvg, FoldIOTestSupport.s(svg["overlapFlip"]),
                                        "\(name): overlap flip svg")
            FoldIOTestSupport.expectSvg(h, OripaIO.exportFoldedModelSvg(model, mode: 0),
                                        FoldIOTestSupport.s(svg["xray"]), "\(name): xray svg")
            FoldIOTestSupport.expectSvg(h, OripaIO.exportFoldedModelSvg(
                model, mode: 0, options: FoldedModelSvgOptions(wire: true)),
                FoldIOTestSupport.s(svg["wire"]), "\(name): wireframe svg")
            h.expectEqual(overlapSvg.contains("<polygon"), true, "\(name): overlap svg has polygons")
            h.expectEqual(OripaIO.exportFoldedModelSvg(model, mode: 9).contains("<line "), false,
                          "\(name): unknown mode falls back to blank svg")

            // Render data (xray/cross/overlap) built from the folded model.
            if let renderData = object["renderData"] as? [String: Any] {
                try checkRenderData(h, name: name, model: model, renderData: renderData)
            }

            // Repeated folding must be deterministic (clear() at the start of foldWithoutOverlap).
            let repeatModel = fold(cp)
            h.expectEqual(repeatModel.mFaces.count, model.mFaces.count, "\(name): repeated fold face count")
            var repeatError = 0.0
            for index in 0..<min(repeatModel.mFaces.count, model.mFaces.count) {
                let a = repeatModel.mFaces[index].halfEdges
                let b = model.mFaces[index].halfEdges
                for edgeIndex in 0..<min(a.count, b.count) {
                    let aValue = a[edgeIndex].end.valueAfterFold ?? PointDouble(0, 0)
                    let bValue = b[edgeIndex].end.valueAfterFold ?? PointDouble(0, 0)
                    repeatError = max(repeatError, abs(aValue.x - bValue.x), abs(aValue.y - bValue.y))
                }
            }
            h.expectClose(repeatError, 0, accuracy: 1e-9, "\(name): repeated fold deterministic")
        }
    }

    // MARK: - render data

    private static func checkRenderData(
        _ h: TestHarness,
        name: String,
        model: FoldedModel,
        renderData: [String: Any]
    ) throws {
        let xray = GLDataFmXrayCross.getRenderData(model.mVertices, model.mHalfEdges, model.mFaces)
        guard let expectedXray = renderData["xray"] as? [String: Any] else {
            h.fail("\(name): no xray render data fixture")
            return
        }
        FoldIOTestSupport.expectFloatArray(h, xray.cpPointPosition,
                                           FoldIOTestSupport.array(expectedXray["cpPointPosition"]),
                                           "\(name): xray.cpPointPosition")
        FoldIOTestSupport.expectByteArray(h, xray.cpLineType,
                                          FoldIOTestSupport.array(expectedXray["cpLineType"]),
                                          "\(name): xray.cpLineType")
        FoldIOTestSupport.expectIntArray(h, xray.cpLineDrawOrder,
                                         FoldIOTestSupport.array(expectedXray["cpLineDrawOrder"]),
                                         "\(name): xray.cpLineDrawOrder")
        FoldIOTestSupport.expectIntArray(h, xray.cpPolygonDrawOrder,
                                         FoldIOTestSupport.array(expectedXray["cpPolygonDrawOrder"]),
                                         "\(name): xray.cpPolygonDrawOrder")
        FoldIOTestSupport.expectFloatArray(h, xray.fmPointPosition,
                                           FoldIOTestSupport.array(expectedXray["fmPointPosition"]),
                                           "\(name): xray.fmPointPosition")
        FoldIOTestSupport.expectIntArray(h, xray.fmFaceDrawOrder,
                                         FoldIOTestSupport.array(expectedXray["fmFaceDrawOrder"]),
                                         "\(name): xray.fmFaceDrawOrder")
        FoldIOTestSupport.expectIntArray(h, xray.fmBoundaryLineDrawOrder,
                                         FoldIOTestSupport.array(expectedXray["fmBoundaryLineDrawOrder"]),
                                         "\(name): xray.fmBoundaryLineDrawOrder")
        FoldIOTestSupport.expectIntArray(h, xray.fmCreaseLineDrawOrder,
                                         FoldIOTestSupport.array(expectedXray["fmCreaseLineDrawOrder"]),
                                         "\(name): xray.fmCreaseLineDrawOrder")

        // Cut line at the default angle/position (0deg, position 300).
        guard let crossLineData = renderData["crossLine"] as? [String: Any] else {
            h.fail("\(name): no cut line render data fixture")
            return
        }
        let cross = GLDataFmCrossLine.getRenderData(model.mFaces, model.crossLine, 0, 300)
        FoldIOTestSupport.expectFloatArray(h, cross.fmPosition,
                                           FoldIOTestSupport.array(crossLineData["fmPosition"]),
                                           "\(name): crossLine.fmPosition")
        FoldIOTestSupport.expectFloatArray(h, cross.cpPosition,
                                           FoldIOTestSupport.array(crossLineData["cpPosition"]),
                                           "\(name): crossLine.cpPosition")

        // CrossLineManager state/update.
        if let managerData = renderData["crossLineManager"] as? [String: Any] {
            let afterGetNew = FoldIOTestSupport.dict(managerData["afterGetNew"])
            let manager = CrossLineManager()
            manager.getNew(model)
            h.expectEqual(manager.getCurrentCrossLineAngleDeg(),
                          FoldIOTestSupport.i(afterGetNew["angleDeg"]), "\(name): manager angle")
            h.expectEqual(manager.getCurrentCrossLinePosition(),
                          FoldIOTestSupport.i(afterGetNew["position"]), "\(name): manager position")
            if let data = manager.getCrossLineRenderData() {
                FoldIOTestSupport.expectFloatArray(h, data.cpPosition,
                                                   FoldIOTestSupport.array(afterGetNew["cpPosition"]),
                                                   "\(name): manager cpPosition")
                FoldIOTestSupport.expectFloatArray(h, data.fmPosition,
                                                   FoldIOTestSupport.array(afterGetNew["fmPosition"]),
                                                   "\(name): manager fmPosition")
            } else {
                h.fail("\(name): CrossLineManager.getNew returned no data")
            }
            let afterUpdate = FoldIOTestSupport.dict(managerData["afterUpdate"])
            manager.updateCrossLineRenderData(model, angleDeg: 90, position: 150)
            h.expectEqual(manager.getCurrentCrossLineAngleDeg(), 90, "\(name): manager updated angle")
            h.expectEqual(manager.getCurrentCrossLinePosition(), 150, "\(name): manager updated position")
            if let data = manager.getCrossLineRenderData() {
                FoldIOTestSupport.expectFloatArray(h, data.cpPosition,
                                                   FoldIOTestSupport.array(afterUpdate["cpPosition"]),
                                                   "\(name): manager updated cpPosition")
            }
        }

        // Overlap split data (front/reverse two-color sets).
        for (key, withShadow) in [("overlapSplitNoShadow", false), ("overlapSplitWithShadow", true)] {
            guard let expectedSets = renderData[key] as? [Any] else { continue }
            let actualSets = GLDataFmOverlap.getRenderDataSplit(
                model.sortedFaces, model.sortedFacesReverse, withShadow)
            h.expectEqual(actualSets.count, expectedSets.count, "\(name): \(key) set count")
            for (index, expectedEntry) in expectedSets.enumerated() where index < actualSets.count {
                FoldIOTestSupport.expectOverlap(h, actualSets[index],
                                                FoldIOTestSupport.dict(expectedEntry),
                                                "\(name): \(key)[\(index)]")
            }
        }
    }

    // MARK: - robustness

    private static func robustness(_ h: TestHarness) throws {
        let fixture = try FoldIOTestSupport.json("Fixtures/foldio/cases.json")

        // Empty CP: not flat-foldable, folding yields an empty model (Java would throw).
        let empty = CreasePattern()
        h.expectEqual(empty.isFlatFoldable(), false, "empty CP is not flat-foldable")
        let emptyModel = FoldedModel()
        emptyModel.foldWithoutOverlap(empty)
        emptyModel.foldWithOverlap()
        h.expectEqual(emptyModel.mFaces.count, 0, "empty CP fold has no faces")
        h.expectEqual(emptyModel.sortedFaces.count, 0, "empty CP fold has no draw order")
        h.expectEqual(emptyModel.componentCount, 0, "empty CP fold has no components")

        // Single line CP: not flat-foldable.
        let single = CreasePattern()
        single.addLineCheckNoException(OriLine(OriPoint(-100, 0), OriPoint(100, 0), LineType.valley))
        h.expectEqual(single.isFlatFoldable(), false, "single line CP is not flat-foldable")

        let scenarios = FoldIOTestSupport.dict(fixture["scenarios"])

        // Auxiliary type-4 lines (116/380 real corpus files contain them) must not break the
        // fold check or create extra faces.
        let auxiliary = FoldIOTestSupport.dict(scenarios["auxiliaryType4Line"])
        let auxiliaryCp = try FoldIOTestSupport.loadCase(FoldIOTestSupport.s(auxiliary["baseCase"]))
        let extraLine = FoldIOTestSupport.dict(auxiliary["extraLine"])
        let extraStart = FoldIOTestSupport.parsePoint(extraLine["start"])
        let extraEnd = FoldIOTestSupport.parsePoint(extraLine["end"])
        auxiliaryCp.addLineCheckNoException(OriLine(
            OriPoint(extraStart.x, extraStart.y), OriPoint(extraEnd.x, extraEnd.y),
            LineType(rawValue: FoldIOTestSupport.i(extraLine["type"])) ?? .undefined))
        h.expectEqual(auxiliaryCp.isFlatFoldable(), FoldIOTestSupport.b(auxiliary["flatFoldable"]),
                      "auxiliary type-4 line: isFlatFoldable")
        let auxiliaryModel = fold(auxiliaryCp)
        h.expectEqual(auxiliaryModel.mFaces.count, FoldIOTestSupport.i(auxiliary["faces"]),
                      "auxiliary type-4 line: face count")
        var finite = true
        for vertex in auxiliaryModel.mVertices {
            guard let value = vertex.valueAfterFold else {
                finite = false
                continue
            }
            if !value.x.isFinite || !value.y.isFinite { finite = false }
        }
        h.expect(finite, "auxiliary type-4 line: folded vertices are finite")

        // Fold, edit the CP (add an auxiliary line), fold again into the same model object.
        let edit = FoldIOTestSupport.dict(scenarios["foldAfterEdit"])
        let editCp = try FoldIOTestSupport.loadCase(FoldIOTestSupport.s(edit["baseCase"]))
        _ = editCp.isFlatFoldable()
        let editModel = FoldedModel()
        editModel.foldWithoutOverlap(editCp)
        editModel.foldWithOverlap()
        h.expectEqual(editModel.mFaces.count, FoldIOTestSupport.i(edit["facesBeforeEdit"]),
                      "fold after edit: face count before")
        let editLine = FoldIOTestSupport.dict(edit["extraLine"])
        let editStart = FoldIOTestSupport.parsePoint(editLine["start"])
        let editEnd = FoldIOTestSupport.parsePoint(editLine["end"])
        editCp.addLineCheckNoException(OriLine(
            OriPoint(editStart.x, editStart.y), OriPoint(editEnd.x, editEnd.y),
            LineType(rawValue: FoldIOTestSupport.i(editLine["type"])) ?? .undefined))
        h.expectEqual(editCp.isFlatFoldable(), FoldIOTestSupport.b(edit["flatAfterEdit"]),
                      "fold after edit: flat foldable")
        editModel.foldWithoutOverlap(editCp)
        editModel.foldWithOverlap()
        h.expectEqual(editModel.mFaces.count, FoldIOTestSupport.i(edit["facesAfterEdit"]),
                      "fold after edit: face count after")
    }
}

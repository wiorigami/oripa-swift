// Folded-model engine test suites. OWNER: fold-engine.
//
// Golden JSON comes from the reference JavaScript implementation via
// tools/fixtures/foldio/gen_foldio.js (CI never runs Node):
//   Fixtures/foldio/engine.json   FoldedModel on programmatic facesCheck polygons (counts,
//                                 valueAfterFold, face matrices, draw orders, CrossLine, manager)
//   Fixtures/foldio/cases.json    folded results for the real Fixtures/cases/** oracle files
//
// The engine suites only need the `FoldedModel`/`OriFace`/`OriHalfEdge`/`OriVertex`/`CrossLine`/
// `CrossLineManager` types plus `foldWithoutOverlap(facesCheck:)`; the case suite additionally
// uses core-model's `CreasePattern.isFlatFoldable()` and fold-io's `OripaIO` loaders.
import Foundation
import ORIPACore

// MARK: - Fixture schema (mirrors gen_foldio.js)

private struct PointFixture: Decodable {
    let x: Double
    let y: Double
}

private struct EngineFixture: Decodable {
    let crossLine: EngineCrossLineFixture
    let models: [EngineModelFixture]
}

private struct EngineCrossLineFixture: Decodable {
    let halfSize200: CrossLineFixture
    let halfSize50: CrossLineFixture
    let segments: [CrossLineSegmentFixture]
}

private struct CrossLineFixture: Decodable {
    let getCrossLineHalfLength: Double
    let angleDegDefault: Int
    let angleDegMax: Int
    let positionMin: Int
    let positionMax: Int
    let positionDefault: Int
}

private struct CrossLineSegmentFixture: Decodable {
    let angleDeg: Int
    let position: Int
    let start: PointFixture
    let end: PointFixture
}

private struct EngineModelFixture: Decodable {
    let name: String
    let foldedModelHalfSizeArgument: Double
    let facesCheck: [FacesCheckFixture]
    let folded: FoldedFixture
    let renderData: EngineRenderDataFixture?
}

private struct FacesCheckFixture: Decodable {
    let points: [PointFixture]
    let lineTypes: [Int]
}

private struct FoldedFixture: Decodable {
    let foldedModelHalfSize: Double
    let faces: Int
    let vertices: Int
    let halfEdges: Int
    let componentCount: Int
    let maxMatrixError: Double
    let sortedFaces: [Int]
    let sortedFacesReverse: [Int]
    let vertexData: [VertexFixture]
    let faceData: [FaceFixture]
}

private struct VertexFixture: Decodable {
    let x: Double
    let y: Double
    let index: Int
    let foldedX: Double
    let foldedY: Double
}

private struct FaceFixture: Decodable {
    let index: Int
    let isCCW: Bool
    let matrix: [Double]
    let halfEdges: [HalfEdgeFixture]
}

private struct HalfEdgeFixture: Decodable {
    let start: Int
    let end: Int
    let lineType: Int
    let twinStart: Int
    let twinEnd: Int
}

private struct EngineRenderDataFixture: Decodable {
    let crossLineManager: CrossLineManagerFixture
}

private struct CrossLineManagerFixture: Decodable {
    let afterGetNew: CrossLineManagerStateFixture
    let afterUpdate: CrossLineManagerStateFixture
}

private struct CrossLineManagerStateFixture: Decodable {
    let angleDeg: Int
    let position: Int
    let cpPosition: [Double]
    let fmPosition: [Double]
}

private struct CasesFixture: Decodable {
    let cases: [CaseFixture]
    let scenarios: ScenariosFixture
}

private struct CaseFixture: Decodable {
    let name: String
    let loader: String
    let cpHalfSize: Double
    let lineCount: Int
    let lines: [LineFixture]
    let flatFoldable: Bool
    let facesCheckCount: Int
    let pointErrorCount: Int
    let errorPoints: [PointFixture]
    let folded: FoldedFixture?
    let repeatMaxError: Double?
}

private struct LineFixture: Decodable {
    let type: Int
    let start: PointFixture
    let end: PointFixture
}

private struct ScenariosFixture: Decodable {
    let auxiliaryType4Line: AuxiliaryType4LineScenarioFixture
    let foldAfterEdit: FoldAfterEditScenarioFixture
}

private struct AuxiliaryType4LineScenarioFixture: Decodable {
    let baseCase: String
    let extraLine: LineFixture
    let flatFoldable: Bool
    let faces: Int
}

private struct FoldAfterEditScenarioFixture: Decodable {
    let baseCase: String
    let extraLine: LineFixture
    let flatAfterEdit: Bool
    let facesBeforeEdit: Int
    let facesAfterEdit: Int
}

// MARK: - Helpers

private enum FoldModelFixtureLoader {
    static func engine() throws -> EngineFixture {
        try Fixtures.decode(EngineFixture.self, "Fixtures/foldio/engine.json")
    }

    static func cases() throws -> CasesFixture {
        try Fixtures.decode(CasesFixture.self, "Fixtures/foldio/cases.json")
    }
}

/// `expectNotNil` keeps the caller's message in the failure report (the shared harness's
/// version records a generic "expected non-nil").
private func requireNotNil<T>(
    _ h: TestHarness,
    _ value: T?,
    _ message: @autoclosure () -> String
) -> T? {
    h.expect(value != nil, "\(message()): expected non-nil")
    return value
}

private func makeFacesCheck(_ fixture: [FacesCheckFixture]) -> [OriPolygon] {
    fixture.map { polygon in
        OriPolygon(
            polygon.points.map { OriPoint($0.x, $0.y) },
            polygon.lineTypes)
    }
}

private func makeFoldedModel(_ fixture: EngineModelFixture) -> FoldedModel {
    let model = FoldedModel(foldedModelHalfSize: fixture.foldedModelHalfSizeArgument)
    model.foldWithoutOverlap(facesCheck: makeFacesCheck(fixture.facesCheck))
    model.foldWithOverlap()
    return model
}

/// `GLUtil` matrix-vs-`valueAfterFold` consistency, computed exactly like gen_foldio.js.
private func matrixError(_ foldedModel: FoldedModel) -> Double {
    var maxError = 0.0
    for face in foldedModel.mFaces {
        for halfEdge in face.halfEdges {
            let transformed = GLUtil.getTransformedPointDouble(
                face.transformMatrix, Float(halfEdge.start.x), Float(halfEdge.start.y))
            guard let valueAfterFold = halfEdge.start.valueAfterFold else { continue }
            maxError = max(maxError, abs(transformed.x - valueAfterFold.x),
                           abs(transformed.y - valueAfterFold.y))
        }
    }
    return maxError
}

/// Structural + numeric comparison of a folded model against `dumpFolded()` in gen_foldio.js.
private func foldModelClose(
    _ h: TestHarness,
    _ foldedModel: FoldedModel,
    _ golden: FoldedFixture,
    _ label: String,
    accuracy: Double = 1e-9
) {
    h.expectEqual(foldedModel.foldedModelHalfSize, golden.foldedModelHalfSize, "\(label) halfSize")
    h.expectEqual(foldedModel.mFaces.count, golden.faces, "\(label) face count")
    h.expectEqual(foldedModel.mVertices.count, golden.vertices, "\(label) vertex count")
    h.expectEqual(foldedModel.mHalfEdges.count, golden.halfEdges, "\(label) half-edge count")
    h.expectEqual(foldedModel.componentCount, golden.componentCount, "\(label) componentCount")
    h.expectEqual(foldedModel.sortedFaces.map { $0.index }, golden.sortedFaces, "\(label) sortedFaces")
    h.expectEqual(foldedModel.sortedFacesReverse.map { $0.index }, golden.sortedFacesReverse,
                  "\(label) sortedFacesReverse")
    h.expectClose(matrixError(foldedModel), golden.maxMatrixError, accuracy: 1e-6,
                  "\(label) maxMatrixError")

    h.expectEqual(foldedModel.mVertices.count, golden.vertexData.count, "\(label) vertexData count")
    for (index, expected) in golden.vertexData.enumerated() where index < foldedModel.mVertices.count {
        let vertex = foldedModel.mVertices[index]
        h.expectEqual(vertex.index, expected.index, "\(label) vertex[\(index)].index")
        h.expectClose(vertex.x, expected.x, accuracy: accuracy, "\(label) vertex[\(index)].x")
        h.expectClose(vertex.y, expected.y, accuracy: accuracy, "\(label) vertex[\(index)].y")
        guard let valueAfterFold = requireNotNil(h, vertex.valueAfterFold, "\(label) vertex[\(index)] folded") else {
            continue
        }
        h.expectClose(valueAfterFold.x, expected.foldedX, accuracy: accuracy,
                      "\(label) vertex[\(index)].foldedX")
        h.expectClose(valueAfterFold.y, expected.foldedY, accuracy: accuracy,
                      "\(label) vertex[\(index)].foldedY")
    }

    h.expectEqual(foldedModel.mFaces.count, golden.faceData.count, "\(label) faceData count")
    for (index, expected) in golden.faceData.enumerated() where index < foldedModel.mFaces.count {
        let face = foldedModel.mFaces[index]
        h.expectEqual(face.index, expected.index, "\(label) face[\(index)].index")
        h.expectEqual(face.isCCWOrientation, expected.isCCW, "\(label) face[\(index)].isCCW")
        h.expectEqual(face.transformMatrix.count, 16, "\(label) face[\(index)] matrix length")
        for element in 0..<min(16, expected.matrix.count) {
            h.expectClose(Double(face.transformMatrix[element]), expected.matrix[element],
                          accuracy: accuracy, "\(label) face[\(index)].matrix[\(element)]")
        }
        h.expectEqual(face.halfEdges.count, expected.halfEdges.count,
                      "\(label) face[\(index)] half-edge count")
        for (edgeIndex, expectedEdge) in expected.halfEdges.enumerated()
        where edgeIndex < face.halfEdges.count {
            let halfEdge = face.halfEdges[edgeIndex]
            h.expectEqual(halfEdge.start.index, expectedEdge.start,
                          "\(label) face[\(index)].edge[\(edgeIndex)].start")
            h.expectEqual(halfEdge.end.index, expectedEdge.end,
                          "\(label) face[\(index)].edge[\(edgeIndex)].end")
            h.expectEqual(halfEdge.lineType, expectedEdge.lineType,
                          "\(label) face[\(index)].edge[\(edgeIndex)].lineType")
            h.expectEqual(halfEdge.twin?.start.index ?? -1, expectedEdge.twinStart,
                          "\(label) face[\(index)].edge[\(edgeIndex)].twinStart")
            h.expectEqual(halfEdge.twin?.end.index ?? -1, expectedEdge.twinEnd,
                          "\(label) face[\(index)].edge[\(edgeIndex)].twinEnd")
        }
    }
}

/// Fold-model invariants from the JS fold tests (independent of the golden dump).
private func foldModelInvariants(
    _ h: TestHarness,
    _ foldedModel: FoldedModel,
    _ label: String
) {
    // Draw orders contain every face exactly once.
    let faceIndices = Set(foldedModel.mFaces.map { $0.index })
    h.expectEqual(Set(foldedModel.sortedFaces.map { $0.index }), faceIndices, "\(label) sortedFaces perm")
    h.expectEqual(Set(foldedModel.sortedFacesReverse.map { $0.index }), faceIndices,
                  "\(label) sortedFacesReverse perm")
    h.expectEqual(foldedModel.sortedFaces.count, foldedModel.mFaces.count, "\(label) draw order len")
    h.expectEqual(foldedModel.sortedFacesReverse.count, foldedModel.mFaces.count,
                  "\(label) reverse draw order len")

    // Twin pairing is mutual and preserves line type/direction. Boundary edges without a
    // reversed partner legitimately keep `twin == nil` (Java leaves them unpaired), so only
    // the existing pairs are asserted.
    var pairedHalfEdgeCount = 0
    for halfEdge in foldedModel.mHalfEdges {
        guard let twin = halfEdge.twin else { continue }
        pairedHalfEdgeCount += 1
        h.expectEqual(twin.start.index, halfEdge.end.index, "\(label) twin start")
        h.expectEqual(twin.end.index, halfEdge.start.index, "\(label) twin end")
        h.expectEqual(twin.lineType, halfEdge.lineType, "\(label) twin lineType")
        h.expect(twin.twin === halfEdge, "\(label) twin back-reference")
    }
    h.expect(pairedHalfEdgeCount % 2 == 0, "\(label) paired half-edge count is even")

    // Every vertex is folded into [-halfSize, halfSize] and every face matrix agrees with it.
    for vertex in foldedModel.mVertices {
        guard let valueAfterFold = requireNotNil(h, vertex.valueAfterFold,
                                                    "\(label) vertex \(vertex.index) folded") else { continue }
        h.expect(abs(valueAfterFold.x) <= foldedModel.foldedModelHalfSize + 1e-3,
                 "\(label) vertex \(vertex.index) foldedX in range: \(valueAfterFold.x)")
        h.expect(abs(valueAfterFold.y) <= foldedModel.foldedModelHalfSize + 1e-3,
                 "\(label) vertex \(vertex.index) foldedY in range: \(valueAfterFold.y)")
    }
    h.expect(matrixError(foldedModel) < 5e-4, "\(label) matrix/valueAfterFold consistency")

    for face in foldedModel.mFaces {
        h.expect(face.halfEdges.count >= 3, "\(label) face \(face.index) has >= 3 edges")
        for halfEdge in face.halfEdges {
            h.expect(halfEdge.lineType == 1 || halfEdge.lineType == 2 || halfEdge.lineType == 3,
                     "\(label) face \(face.index) folded edge lineType \(halfEdge.lineType)")
            h.expect(halfEdge.face === face, "\(label) face \(face.index) edge back-reference")
        }
    }
}

private func crossLineNumbersClose(
    _ h: TestHarness,
    _ actual: [Float],
    _ expected: [Double],
    _ label: String,
    accuracy: Double = 1e-5
) {
    h.expectEqual(actual.count, expected.count, "\(label) count")
    for index in 0..<min(actual.count, expected.count) {
        h.expectClose(Double(actual[index]), expected[index], accuracy: accuracy,
                      "\(label)[\(index)]")
    }
}

private func loadCase(_ name: String) throws -> CreasePattern {
    let data = try Fixtures.data("Fixtures/cases/" + name)
    return try OripaIO.loadCreasePattern(data: data, filenameWithExt: name)
}

private func oriLine(_ fixture: LineFixture) -> OriLine {
    OriLine(OriPoint(fixture.start.x, fixture.start.y),
            OriPoint(fixture.end.x, fixture.end.y),
            fixture.type)
}

// MARK: - Suites

private enum FoldModelCrossLineSuite {
    static var all: [TestSuite] {
        [TestSuite("FoldModel.CrossLine") { h in try run(h) }]
    }

    private static func run(_ h: TestHarness) throws {
            let engine = try FoldModelFixtureLoader.engine()
            let crossLine = engine.crossLine

            let expected200 = crossLine.halfSize200
            let line200 = CrossLine(200.0)
            h.expectClose(line200.getCrossLineHalfLength(), expected200.getCrossLineHalfLength,
                          "halfSize200 halfLength")
            h.expectEqual(line200.getAngleDegDefaultMagnitude(), expected200.angleDegDefault,
                          "halfSize200 angleDegDefault")
            h.expectEqual(line200.getAngleDegMaxMagnitude(), expected200.angleDegMax,
                          "halfSize200 angleDegMax")
            h.expectEqual(line200.getPositionMinMagnitude(), expected200.positionMin,
                          "halfSize200 positionMin")
            h.expectEqual(line200.getPositionMaxMagnitude(), expected200.positionMax,
                          "halfSize200 positionMax")
            h.expectEqual(line200.getPositionDefaultMagnitude(), expected200.positionDefault,
                          "halfSize200 positionDefault")
            h.expectEqual(line200.foldedModelHalfSize, 200.0, "halfSize200 field")

            let expected50 = crossLine.halfSize50
            let line50 = CrossLine(50.0)
            h.expectClose(line50.getCrossLineHalfLength(), expected50.getCrossLineHalfLength,
                          "halfSize50 halfLength")
            h.expectEqual(line50.getAngleDegDefaultMagnitude(), expected50.angleDegDefault,
                          "halfSize50 angleDegDefault")
            h.expectEqual(line50.getPositionMaxMagnitude(), expected50.positionMax,
                          "halfSize50 positionMax")
            h.expectEqual(line50.getPositionDefaultMagnitude(), expected50.positionDefault,
                          "halfSize50 positionDefault")

            for expected in crossLine.segments {
                let segment = line200.getFmCrossLine(angleDeg: expected.angleDeg, position: expected.position)
                h.expectClose(segment.start.x, expected.start.x, "angle \(expected.angleDeg) start.x")
                h.expectClose(segment.start.y, expected.start.y, "angle \(expected.angleDeg) start.y")
                h.expectClose(segment.end.x, expected.end.x, "angle \(expected.angleDeg) end.x")
                h.expectClose(segment.end.y, expected.end.y, "angle \(expected.angleDeg) end.y")
            }

            // Default magnitude comes from Constant.SINGLE_GRID_IMAGE_DIMEN_DP (Android 180).
            h.expectEqual(line200.getAngleDegDefaultMagnitude(), Constant.SINGLE_GRID_IMAGE_DIMEN_DP,
                          "angle default = SINGLE_GRID_IMAGE_DIMEN_DP")
            // Convenience initializer label parity with the Java `CrossLine(double)`.
            let copy = CrossLine(foldedModelHalfSize: 200.0)
            h.expectEqual(copy.getPositionMaxMagnitude(), 600, "labelled init positionMax")
    }
}

private enum FoldModelEngineSuite {
    static var all: [TestSuite] {
        [TestSuite("FoldModel.Engine") { h in try run(h) }]
    }

    private static func run(_ h: TestHarness) throws {
            let engine = try FoldModelFixtureLoader.engine()
            h.expect(engine.models.count >= 5, "fixture model count \(engine.models.count)")
            for fixture in engine.models {
                let foldedModel = makeFoldedModel(fixture)
                foldModelClose(h, foldedModel, fixture.folded, fixture.name)
                foldModelInvariants(h, foldedModel, fixture.name)
            }

            // Repeated folding is deterministic (gen_foldio.js `repeatMaxError`).
            for fixture in engine.models where !fixture.facesCheck.isEmpty {
                let first = makeFoldedModel(fixture)
                let second = makeFoldedModel(fixture)
                var repeatError = 0.0
                for faceIndex in 0..<min(first.mFaces.count, second.mFaces.count) {
                    let a = first.mFaces[faceIndex].halfEdges
                    let b = second.mFaces[faceIndex].halfEdges
                    for edgeIndex in 0..<min(a.count, b.count) {
                        guard let av = a[edgeIndex].end.valueAfterFold,
                              let bv = b[edgeIndex].end.valueAfterFold else { continue }
                        repeatError = max(repeatError, abs(av.x - bv.x), abs(av.y - bv.y))
                    }
                }
                h.expectEqual(repeatError, 0.0, "\(fixture.name) repeat error")
            }
    }
}

private enum FoldModelCrossLineManagerSuite {
    static var all: [TestSuite] {
        [TestSuite("FoldModel.CrossLineManager") { h in try run(h) }]
    }

    private static func run(_ h: TestHarness) throws {
            let engine = try FoldModelFixtureLoader.engine()
            let manager = CrossLineManager()
            h.expectEqual(manager.getCurrentCrossLineAngleDeg(), 0, "initial angle")
            h.expectEqual(manager.getCurrentCrossLinePosition(), 0, "initial position")
            h.expectNil(manager.getCrossLineRenderData(), "initial render data")

            for fixture in engine.models where !fixture.facesCheck.isEmpty {
                let renderData = requireNotNil(h, fixture.renderData, "\(fixture.name) render data")
                guard let renderData else { continue }
                let foldedModel = makeFoldedModel(fixture)

                manager.getNew(foldedModel)
                let expectedNew = renderData.crossLineManager.afterGetNew
                h.expectEqual(manager.getCurrentCrossLineAngleDeg(), expectedNew.angleDeg,
                              "\(fixture.name) getNew angle")
                h.expectEqual(manager.getCurrentCrossLinePosition(), expectedNew.position,
                              "\(fixture.name) getNew position")
                guard let newData = requireNotNil(h, manager.getCrossLineRenderData(),
                                                 "\(fixture.name) getNew render data") else { continue }
                crossLineNumbersClose(h, newData.cpPosition, expectedNew.cpPosition,
                                      "\(fixture.name) getNew cpPosition")
                crossLineNumbersClose(h, newData.fmPosition, expectedNew.fmPosition,
                                      "\(fixture.name) getNew fmPosition")

                manager.updateCrossLineRenderData(foldedModel, angleDeg: 90, position: 150)
                let expectedUpdate = renderData.crossLineManager.afterUpdate
                h.expectEqual(manager.getCurrentCrossLineAngleDeg(), expectedUpdate.angleDeg,
                              "\(fixture.name) update angle")
                h.expectEqual(manager.getCurrentCrossLinePosition(), expectedUpdate.position,
                              "\(fixture.name) update position")
                guard let updateData = requireNotNil(h, manager.getCrossLineRenderData(),
                                                    "\(fixture.name) update render data") else { continue }
                crossLineNumbersClose(h, updateData.cpPosition, expectedUpdate.cpPosition,
                                      "\(fixture.name) update cpPosition")
                crossLineNumbersClose(h, updateData.fmPosition, expectedUpdate.fmPosition,
                                      "\(fixture.name) update fmPosition")

                manager.clear()
                h.expectEqual(manager.getCurrentCrossLineAngleDeg(), 0, "\(fixture.name) clear angle")
                h.expectEqual(manager.getCurrentCrossLinePosition(), 0, "\(fixture.name) clear position")
                h.expectNil(manager.getCrossLineRenderData(), "\(fixture.name) clear render data")
            }
    }
}

private enum FoldModelApiSuite {
    static var all: [TestSuite] {
        [TestSuite("FoldModel.Api") { h in try run(h) }]
    }

    private static func run(_ h: TestHarness) throws {
            // FoldOverlapParams constants (Java byte values).
            h.expectEqual(FoldOverlapParams.TYPE_FACE_FRONT, 0, "TYPE_FACE_FRONT")
            h.expectEqual(FoldOverlapParams.TYPE_FACE_BACK, 1, "TYPE_FACE_BACK")
            h.expectEqual(FoldOverlapParams.TYPE_LINE, 2, "TYPE_LINE")
            h.expectEqual(FoldOverlapParams.TYPE_SHADOW_INNER, 3, "TYPE_SHADOW_INNER")
            h.expectEqual(FoldOverlapParams.TYPE_SHADOW_OUTER, 4, "TYPE_SHADOW_OUTER")

            // Java `FoldedModel()` default half size 200 (private FoldedModel(double) role).
            let defaultModel = FoldedModel()
            h.expectEqual(defaultModel.foldedModelHalfSize, 200.0, "default half size")
            h.expectEqual(defaultModel.crossLine.foldedModelHalfSize, 200.0, "default crossLine halfSize")
            h.expectEqual(defaultModel.mFaces.count, 0, "default faces")
            h.expectEqual(defaultModel.mVertices.count, 0, "default vertices")
            h.expectEqual(defaultModel.mHalfEdges.count, 0, "default halfEdges")
            h.expectEqual(defaultModel.sortedFaces.count, 0, "default sortedFaces")
            h.expectEqual(defaultModel.sortedFacesReverse.count, 0, "default sortedFacesReverse")
            h.expectEqual(defaultModel.componentCount, 0, "default componentCount")

            let custom = FoldedModel(foldedModelHalfSize: 50.0)
            h.expectEqual(custom.foldedModelHalfSize, 50.0, "custom half size")
            h.expectEqual(custom.crossLine.getPositionMaxMagnitude(), 150, "custom crossLine")

            // Empty facesCheck: empty model, no crash (JS port guard; Java threw).
            let empty = FoldedModel()
            empty.foldWithoutOverlap(facesCheck: [])
            h.expectEqual(empty.mFaces.count, 0, "empty model faces")
            h.expectEqual(empty.componentCount, 0, "empty model componentCount")
            empty.foldWithOverlap()
            h.expectEqual(empty.sortedFaces.count, 0, "empty model sortedFaces")

            // clear() resets everything.
            let engine = try FoldModelFixtureLoader.engine()
            guard let fixture = engine.models.first(where: { $0.name == "squareBase100" }) else {
                h.fail("missing squareBase100 fixture")
                return
            }
            let foldedModel = makeFoldedModel(fixture)
            h.expectEqual(foldedModel.mFaces.count, 4, "squareBase faces")
            foldedModel.clear()
            h.expectEqual(foldedModel.mFaces.count, 0, "clear faces")
            h.expectEqual(foldedModel.mVertices.count, 0, "clear vertices")
            h.expectEqual(foldedModel.mHalfEdges.count, 0, "clear halfEdges")
            h.expectEqual(foldedModel.sortedFaces.count, 0, "clear sortedFaces")
            h.expectEqual(foldedModel.sortedFacesReverse.count, 0, "clear sortedFacesReverse")
            h.expectEqual(foldedModel.componentCount, 0, "clear componentCount")

            // Refolding the same instance works (foldWithoutOverlap calls clear() first).
            foldedModel.foldWithoutOverlap(facesCheck: makeFacesCheck(fixture.facesCheck))
            foldedModel.foldWithOverlap()
            foldModelClose(h, foldedModel, fixture.folded, "refold squareBase100")
    }
}

private enum FoldModelCasesSuite {
    static var all: [TestSuite] {
        [TestSuite("FoldModel.Cases") { h in try run(h) }]
    }

    private static func run(_ h: TestHarness) throws {
            let fixture = try FoldModelFixtureLoader.cases()
            h.expect(fixture.cases.count >= 6, "case count \(fixture.cases.count)")

            for expected in fixture.cases {
                let creasePattern = try loadCase(expected.name)
                h.expectEqual(creasePattern.creasePatternHalfSize, Float(expected.cpHalfSize),
                              "\(expected.name) cpHalfSize")

                let flatFoldable = creasePattern.isFlatFoldable()
                h.expectEqual(flatFoldable, expected.flatFoldable, "\(expected.name) isFlatFoldable")
                h.expectEqual(creasePattern.facesCheck.count, expected.facesCheckCount,
                              "\(expected.name) facesCheck count")
                h.expectEqual(creasePattern.pointErrorCheck.count, expected.pointErrorCount,
                              "\(expected.name) pointErrorCheck count")
                let errorPoints: [(x: Double, y: Double)] = creasePattern.pointErrorCheck.map { point in
                    (x: point.x, y: point.y)
                }
                let sortedErrorPoints = errorPoints.sorted { lhs, rhs in
                    if lhs.x != rhs.x { return lhs.x < rhs.x }
                    return lhs.y < rhs.y
                }
                h.expectEqual(sortedErrorPoints.count, expected.errorPoints.count,
                              "\(expected.name) error point count")
                for index in 0..<min(sortedErrorPoints.count, expected.errorPoints.count) {
                    h.expectClose(sortedErrorPoints[index].x, expected.errorPoints[index].x,
                                  "\(expected.name) error point[\(index)].x")
                    h.expectClose(sortedErrorPoints[index].y, expected.errorPoints[index].y,
                                  "\(expected.name) error point[\(index)].y")
                }

                guard expected.flatFoldable, let golden = expected.folded else { continue }
                let foldedModel = FoldedModel()
                foldedModel.foldWithoutOverlap(creasePattern)
                foldedModel.foldWithOverlap()
                foldModelClose(h, foldedModel, golden, expected.name, accuracy: 1e-6)
                foldModelInvariants(h, foldedModel, expected.name)
                h.expectEqual(foldedModel.componentCount, 1, "\(expected.name) single component")

                // Repeated fold determinism (gen_foldio.js `repeatMaxError`).
                let repeatModel = FoldedModel()
                repeatModel.foldWithoutOverlap(creasePattern)
                repeatModel.foldWithOverlap()
                var repeatError = 0.0
                for faceIndex in 0..<min(foldedModel.mFaces.count, repeatModel.mFaces.count) {
                    let a = foldedModel.mFaces[faceIndex].halfEdges
                    let b = repeatModel.mFaces[faceIndex].halfEdges
                    for edgeIndex in 0..<min(a.count, b.count) {
                        guard let av = a[edgeIndex].end.valueAfterFold,
                              let bv = b[edgeIndex].end.valueAfterFold else { continue }
                        repeatError = max(repeatError, abs(av.x - bv.x), abs(av.y - bv.y))
                    }
                }
                h.expectClose(repeatError, expected.repeatMaxError ?? 0.0, accuracy: 1e-9,
                              "\(expected.name) repeat error")
            }

            // Robustness scenarios from tools/tests/test_fold_oracle_cases.js.
            let auxiliary = fixture.scenarios.auxiliaryType4Line
            let auxiliaryCp = try loadCase(auxiliary.baseCase)
            auxiliaryCp.addLineCheckNoException(oriLine(auxiliary.extraLine))
            let auxiliaryFlat = auxiliaryCp.isFlatFoldable()
            h.expectEqual(auxiliaryFlat, auxiliary.flatFoldable, "auxiliary type4 flatFoldable")
            let auxiliaryModel = FoldedModel()
            auxiliaryModel.foldWithoutOverlap(auxiliaryCp)
            h.expectEqual(auxiliaryModel.mFaces.count, auxiliary.faces, "auxiliary type4 faces")
            h.expectEqual(auxiliaryModel.componentCount, 1, "auxiliary type4 components")

            let edit = fixture.scenarios.foldAfterEdit
            let editCp = try loadCase(edit.baseCase)
            _ = editCp.isFlatFoldable()
            let editModel = FoldedModel()
            editModel.foldWithoutOverlap(editCp)
            editModel.foldWithOverlap()
            h.expectEqual(editModel.mFaces.count, edit.facesBeforeEdit, "foldAfterEdit faces before")
            editCp.addLineCheckNoException(oriLine(edit.extraLine))
            let editFlat = editCp.isFlatFoldable()
            h.expectEqual(editFlat, edit.flatAfterEdit, "foldAfterEdit flatFoldable")
            editModel.foldWithoutOverlap(editCp)
            editModel.foldWithOverlap()
            h.expectEqual(editModel.mFaces.count, edit.facesAfterEdit, "foldAfterEdit faces after")
    }
}

// MARK: - Registry (main.swift runs FoldModelTestSuites.all)

enum FoldModelTestSuites {
    static var all: [TestSuite] {
        FoldModelCrossLineSuite.all
            + FoldModelEngineSuite.all
            + FoldModelCrossLineManagerSuite.all
            + FoldModelApiSuite.all
            + FoldModelCasesSuite.all
    }
}

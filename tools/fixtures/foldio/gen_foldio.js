#!/usr/bin/env node
/*
 * fold-io golden fixture generator.
 *
 * Runs the reference JavaScript implementation (oripa-port/src/js) through
 * tools/fixtures/load_oripa.js and writes deterministic JSON that the Swift XCTests
 * under Tests/ORIPACoreTests/FoldIO decode. CI never runs Node.
 *
 *   node tools/fixtures/foldio/gen_foldio.js [--check]
 *
 * Outputs (committed):
 *   Fixtures/foldio/roundtrip.json   file formats (CP/OPX/OPXC/SVG), FileUtil, XmlPullParser,
 *                                    LoaderOpxcToGL, malformed-input behaviour
 *   Fixtures/foldio/cases.json       folded-model results for every Fixtures/cases/** oracle case
 *   Fixtures/foldio/engine.json      FoldedModel engine on programmatic facesCheck polygons
 *                                    (counts, valueAfterFold, matrices, draw orders, CrossLine)
 *   Fixtures/foldio/renderdata.json  GLData* builder outputs for the same CPs
 *
 * The real case files live in Fixtures/cases/ (copied from
 * oripa-port/tools/fold_oracle/cases/** by this script; see copyCases()).
 */
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..", "..");
const O = require(path.join(ROOT, "tools", "fixtures", "load_oripa.js"))();
const OUT_DIR = path.join(ROOT, "Fixtures", "foldio");
const CASES_DIR = path.join(ROOT, "Fixtures", "cases");
const SRC_CASES = path.resolve(ROOT, "..", "oripa-port", "tools", "fold_oracle", "cases");

function text(bytes) {
    return Buffer.from(bytes).toString("utf8");
}

function bn(v) {
    // canonical number for JSON: -0 -> 0 (JSON cannot represent -0 distinctly)
    if (typeof v !== "number") return v;
    if (Object.is(v, -0)) return 0;
    if (!Number.isFinite(v)) throw new Error("non-finite number cannot be stored in JSON: " + v);
    return v;
}

function pt(p) {
    return { x: bn(p.x), y: bn(p.y) };
}

function lineDump(l) {
    return { type: l.type() | 0, start: pt(l.start), end: pt(l.end) };
}

function linesOf(cp) {
    return Array.from(cp.lineMVFB).map(lineDump);
}

function pointsOf(cp) {
    return Array.from(cp.pointMVFB).map(pt);
}

/* ------------------------------------------------------------------ cases */
function readCase(name) {
    return new Uint8Array(fs.readFileSync(path.join(CASES_DIR, name)));
}

function loadCase(name) {
    const bytes = readCase(name);
    const cp = new O.CreasePattern();
    if (/\.opx$/i.test(name)) O.LoaderOpx.getCreasePattern(name, { name, bytes }, cp);
    else O.LoaderCp.getCreasePattern(name, { name, bytes }, cp);
    return cp;
}

function matrixError(fm) {
    let maxErr = 0;
    for (const face of fm.mFaces) {
        for (const he of face.halfEdges) {
            const p = O.GLUtil.getTransformedPointDouble(face.transformMatrix,
                Math.fround(he.start.x), Math.fround(he.start.y));
            const v = he.start.valueAfterFold;
            maxErr = Math.max(maxErr, Math.abs(p.x - v.x), Math.abs(p.y - v.y));
        }
    }
    return bn(maxErr);
}

function arr(a) {
    return Array.from(a).map(bn);
}

function dumpFolded(fm) {
    return {
        foldedModelHalfSize: bn(fm.foldedModelHalfSize),
        faces: fm.mFaces.length,
        vertices: fm.mVertices.length,
        halfEdges: fm.mHalfEdges.length,
        componentCount: fm.componentCount,
        maxMatrixError: matrixError(fm),
        sortedFaces: fm.sortedFaces.map((f) => f.index),
        sortedFacesReverse: fm.sortedFacesReverse.map((f) => f.index),
        vertexData: fm.mVertices.map((v) => ({
            x: bn(v.x),
            y: bn(v.y),
            index: v.index,
            foldedX: bn(v.valueAfterFold.x),
            foldedY: bn(v.valueAfterFold.y),
        })),
        faceData: fm.mFaces.map((face) => ({
            index: face.index,
            isCCW: face.isCCWOrientation,
            matrix: arr(face.transformMatrix),
            halfEdges: face.halfEdges.map((he) => ({
                start: he.start.index,
                end: he.end.index,
                lineType: he.lineType,
                twinStart: he.twin === null ? -1 : he.twin.start.index,
                twinEnd: he.twin === null ? -1 : he.twin.end.index,
            })),
        })),
    };
}

function dumpOverlap(data, compact) {
    const fields = [
        "pointPosition", "pointType", "pointAngleDeg", "drawOrder",
        "reversePointPosition", "reversePointType", "reversePointAngleDeg", "reverseDrawOrder",
    ];
    if (!compact) {
        const out = {};
        for (const field of fields) out[field] = arr(data[field]);
        return out;
    }
    // Big models: store lengths + a sample per array (the small fixtures cover the full
    // encoding; this keeps huge corpus cases cheap while still detecting shape changes).
    const out = { compact: true };
    for (const field of fields) {
        out[field + "Length"] = data[field].length;
        out[field + "Sample"] = arr(Array.prototype.slice.call(data[field], 0, 32));
    }
    return out;
}

function dumpFoldedRenderData(fm) {
    const xray = O.GLDataFmXrayCross.getRenderData(fm.mVertices, fm.mHalfEdges, fm.mFaces);
    const cross = O.GLDataFmCrossLine.getRenderData(fm.mFaces, fm.crossLine, 0, 300);
    const manager = new O.CrossLineManager();
    manager.getNew(fm);
    const afterGetNew = {
        angleDeg: manager.getCurrentCrossLineAngleDeg(),
        position: manager.getCurrentCrossLinePosition(),
        cpPosition: arr(manager.getCrossLineRenderData().cpPosition),
        fmPosition: arr(manager.getCrossLineRenderData().fmPosition),
    };
    manager.updateCrossLineRenderData(fm, 90, 150);
    const afterUpdate = {
        angleDeg: manager.getCurrentCrossLineAngleDeg(),
        position: manager.getCurrentCrossLinePosition(),
        cpPosition: arr(manager.getCrossLineRenderData().cpPosition),
        fmPosition: arr(manager.getCrossLineRenderData().fmPosition),
    };
    return {
        xray: {
            cpPointPosition: arr(xray.cpPointPosition),
            cpLineType: arr(xray.cpLineType),
            cpLineDrawOrder: arr(xray.cpLineDrawOrder),
            cpPolygonDrawOrder: arr(xray.cpPolygonDrawOrder),
            fmPointPosition: arr(xray.fmPointPosition),
            fmFaceDrawOrder: arr(xray.fmFaceDrawOrder),
            fmBoundaryLineDrawOrder: arr(xray.fmBoundaryLineDrawOrder),
            fmCreaseLineDrawOrder: arr(xray.fmCreaseLineDrawOrder),
        },
        crossLine: {
            fmPosition: arr(cross.fmPosition),
            cpPosition: arr(cross.cpPosition),
        },
        crossLineManager: { afterGetNew: afterGetNew, afterUpdate: afterUpdate },
        overlapSplitNoShadow: O.GLDataFmOverlap.getRenderDataSplit(fm.sortedFaces, fm.sortedFacesReverse, false)
            .map((d) => dumpOverlap(d, fm.mFaces.length > 64)),
        overlapSplitWithShadow: O.GLDataFmOverlap.getRenderDataSplit(fm.sortedFaces, fm.sortedFacesReverse, true)
            .map((d) => dumpOverlap(d, fm.mFaces.length > 64)),
    };
}

function svgOf(fm) {
    return {
        overlap: text(O.ExporterSvg.getFoldedModelOverlap(fm, false, -28242, -16730151, -11513776)),
        overlapFlip: text(O.ExporterSvg.getFoldedModelOverlap(fm, true, -28242, -16730151, -11513776)),
        xray: text(O.ExporterSvg.getFoldedModelXray(fm, false)),
        wire: text(O.ExporterSvg.getFoldedModelXray(fm, true)),
    };
}

function buildCases() {
    const names = fs.readdirSync(CASES_DIR).filter((n) => /\.(opx|cp|opxc)$/i.test(n)).sort();
    const cases = [];
    for (const name of names) {
        const cp = loadCase(name);
        const flat = cp.isFlatFoldable();
        const entry = {
            name: name,
            loader: /\.opx$/i.test(name) ? "opx" : (/\.opxc$/i.test(name) ? "opxc" : "cp"),
            cpHalfSize: bn(cp.creasePatternHalfSize),
            lineCount: cp.lineMVFB.size(),
            lines: linesOf(cp),
            flatFoldable: flat,
            facesCheckCount: cp.facesCheck.size(),
            pointErrorCount: cp.pointErrorCheck.size(),
            errorPoints: Array.from(cp.pointErrorCheck).map(pt).sort((a, b) => a.x - b.x || a.y - b.y),
        };
        if (flat) {
            const fm = new O.FoldedModel();
            fm.foldWithoutOverlap(cp);
            fm.foldWithOverlap();
            entry.folded = dumpFolded(fm);
            entry.renderData = dumpFoldedRenderData(fm);
            entry.svg = svgOf(fm);
            // repeated fold determinism
            const fm2 = new O.FoldedModel();
            fm2.foldWithoutOverlap(cp);
            fm2.foldWithOverlap();
            let repeatErr = 0;
            for (let i = 0; i < Math.min(fm2.mFaces.length, fm.mFaces.length); i++) {
                const a = fm.mFaces[i].halfEdges;
                const b = fm2.mFaces[i].halfEdges;
                for (let j = 0; j < Math.min(a.length, b.length); j++) {
                    repeatErr = Math.max(repeatErr,
                        Math.abs(a[j].end.valueAfterFold.x - b[j].end.valueAfterFold.x),
                        Math.abs(a[j].end.valueAfterFold.y - b[j].end.valueAfterFold.y));
                }
            }
            entry.repeatMaxError = bn(repeatErr);
        }
        cases.push(entry);
    }

    // robustness scenarios from tools/tests/test_fold_oracle_cases.js
    const auxCp = loadCase("fold_in_half.cp");
    auxCp.addLineCheckNoException(new O.OriLine(new O.OriPoint(150, -150), new O.OriPoint(-150, 150), 4));
    const auxFlat = auxCp.isFlatFoldable();   // fills facesCheck, as the UI does before folding
    const auxFm = new O.FoldedModel();
    auxFm.foldWithoutOverlap(auxCp);
    const editCp = loadCase("sierpinski_l2.cp");
    editCp.isFlatFoldable();
    const editFm = new O.FoldedModel();
    editFm.foldWithoutOverlap(editCp);
    editFm.foldWithOverlap();
    const editBefore = editFm.mFaces.length;
    editCp.addLineCheckNoException(new O.OriLine(new O.OriPoint(1, 2), new O.OriPoint(3, 4), 4));
    const editFlat = editCp.isFlatFoldable();
    editFm.foldWithoutOverlap(editCp);
    editFm.foldWithOverlap();

    return {
        cases: cases,
        scenarios: {
            auxiliaryType4Line: {
                baseCase: "fold_in_half.cp",
                extraLine: { type: 4, start: { x: 150, y: -150 }, end: { x: -150, y: 150 } },
                flatFoldable: auxFlat,
                faces: auxFm.mFaces.length,
            },
            foldAfterEdit: {
                baseCase: "sierpinski_l2.cp",
                extraLine: { type: 4, start: { x: 1, y: 2 }, end: { x: 3, y: 4 } },
                flatAfterEdit: editFlat,
                facesBeforeEdit: editBefore,
                facesAfterEdit: editFm.mFaces.length,
            },
        },
    };
}

/* ------------------------------------------------------- programmatic models */
function oriPoint(x, y) {
    return new O.OriPoint(x, y);
}

function poly(points, lineTypes) {
    return { points: points, lineTypes: lineTypes };
}

function squareBaseFacesCheck(half) {
    return [
        poly([oriPoint(-half, -half), oriPoint(0, -half), oriPoint(0, 0), oriPoint(-half, 0)],
            [1, 3, 2, 1]),
        poly([oriPoint(0, -half), oriPoint(half, -half), oriPoint(half, 0), oriPoint(0, 0)],
            [1, 1, 2, 3]),
        poly([oriPoint(half, 0), oriPoint(half, half), oriPoint(0, half), oriPoint(0, 0)],
            [1, 1, 3, 2]),
        poly([oriPoint(-half, 0), oriPoint(0, 0), oriPoint(0, half), oriPoint(-half, half)],
            [2, 3, 1, 1]),
    ];
}

function square(x0, y0, x1, y1) {
    return poly([oriPoint(x0, y0), oriPoint(x1, y0), oriPoint(x1, y1), oriPoint(x0, y1)], [1, 1, 1, 1]);
}

function foldModel(name, facesCheck, foldedModelHalfSize, cpHalfSize) {
    const fm = new O.FoldedModel(foldedModelHalfSize);
    fm.foldWithoutOverlap({ creasePatternHalfSize: cpHalfSize === undefined ? 200 : cpHalfSize, facesCheck: new Set(facesCheck) });
    fm.foldWithOverlap();
    const result = {
        name: name,
        foldedModelHalfSizeArgument: bn(fm.foldedModelHalfSize),
        facesCheck: facesCheck.map((f) => ({
            points: f.points.map(pt),
            lineTypes: f.lineTypes.map((t) => t | 0),
        })),
        folded: dumpFolded(fm),
    };
    if (fm.mFaces.length > 0) {
        result.renderData = dumpFoldedRenderData(fm);
        result.svg = svgOf(fm);
    }
    return result;
}

function buildEngine() {
    const crossLine = new O.CrossLine(200);
    const crossSegments = [];
    for (const spec of [[0, 300], [0, 0], [90, 300], [45, 300], [180, 300]]) {
        const segment = crossLine.getFmCrossLine(spec[0], spec[1]);
        crossSegments.push({ angleDeg: spec[0], position: spec[1], start: pt(segment.start), end: pt(segment.end) });
    }
    const crossLine50 = new O.CrossLine(50);
    return {
        crossLine: {
            halfSize200: {
                getCrossLineHalfLength: bn(crossLine.getCrossLineHalfLength()),
                angleDegDefault: crossLine.getAngleDegDefaultMagnitude(),
                angleDegMax: crossLine.getAngleDegMaxMagnitude(),
                positionMin: crossLine.getPositionMinMagnitude(),
                positionMax: crossLine.getPositionMaxMagnitude(),
                positionDefault: crossLine.getPositionDefaultMagnitude(),
            },
            halfSize50: {
                getCrossLineHalfLength: bn(crossLine50.getCrossLineHalfLength()),
                angleDegDefault: crossLine50.getAngleDegDefaultMagnitude(),
                angleDegMax: crossLine50.getAngleDegMaxMagnitude(),
                positionMin: crossLine50.getPositionMinMagnitude(),
                positionMax: crossLine50.getPositionMaxMagnitude(),
                positionDefault: crossLine50.getPositionDefaultMagnitude(),
            },
            segments: crossSegments,
        },
        models: [
            foldModel("squareBase100", squareBaseFacesCheck(100), undefined),
            foldModel("singleSquare200", [square(-200, -200, 200, 200)], undefined),
            foldModel("disconnectedSquares", [
                square(-100, -100, -20, -20),
                square(20, 20, 100, 100),
            ], undefined),
            foldModel("customHalfSize50", squareBaseFacesCheck(100), 50),
            foldModel("empty", [], undefined),
        ],
        blankOverlapSplit: O.GLDataFmOverlap.getRenderDataBlankSplit().map((d) => dumpOverlap(d, false)),
    };
}

/* ------------------------------------------------------------ file formats */
function buildCreasePatternSegmented() {
    const cp = new O.CreasePattern();
    const half = cp.creasePatternHalfSize;
    const corners = [
        [-half, -half], [0, -half], [half, -half],
        [half, half], [0, half], [-half, half],
    ];
    for (let i = 0; i < corners.length; i++) {
        const a = corners[i];
        const b = corners[(i + 1) % corners.length];
        cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(a[0], a[1]), new O.OriPoint(b[0], b[1]), 1));
    }
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(0, -half), new O.OriPoint(0, half), 3));
    return cp;
}

function buildCreasePatternMixed() {
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(-200, -200), new O.OriPoint(200, 200), 2));
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(-100, 0), new O.OriPoint(100, 0), 0));
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(-50, 50), new O.OriPoint(50, 50), 4));
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(0, 0), new O.OriPoint(0.0015, 0.0015), 2));
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(0, 0), new O.OriPoint(400, -400), 3));
    return cp;
}

function buildFileSmall() {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(-10.5, 0.25), new O.OriPoint(10.5, -0.25), 2));
    cp.addLineCheckNoException(new O.OriLine(new O.OriPoint(0, -10), new O.OriPoint(0, 10), 3));
    return cp;
}

function dumpCpCase(name, cp) {
    const exports = {
        opx: text(O.io.exportOpx(cp)),
        opxc: text(O.io.exportOpxc(cp)),
        cp: text(O.io.exportCp(cp)),
        svg: text(O.io.exportSvg(cp)),
    };
    const loaded = {};
    const reexportIdentical = {};
    for (const type of ["opx", "opxc", "cp"]) {
        const target = new O.CreasePattern();
        O.io.loadCreasePattern("x." + type, { name: "x." + type, path: "", bytes: O.io.textToBytes(exports[type]) }, target);
        loaded[type] = linesOf(target);
        reexportIdentical[type] = text(O.io["export" + type[0].toUpperCase() + type.slice(1)](target)) === exports[type];
    }
    return {
        name: name,
        halfSize: bn(cp.creasePatternHalfSize),
        lines: linesOf(cp),
        points: pointsOf(cp),
        exports: exports,
        loadedLines: loaded,
        reexportIdentical: reexportIdentical,
    };
}

function buildRoundtrip() {
    const doubleCases = [
        "400", "0", "-0", "0.001", "0.0001", "0.00001", "10000000", "9999999.5",
        "123.456", "-200", "1.5e-7", "3.4e38", "1.7976931348623157e308", "0.1",
        "-0.000123", "1234567.891", "2.5", "-2.5", "1e-3", "12345678.9",
    ].map((s) => ({ input: s, expected: O.io.doubleToString(Number(s)) }));

    const fileUtil = {
        fileExt: ["pattern.OPX", "pattern.opxc", "pattern", "pattern.", "a.b.C.PNG", ""].map((s) => ({
            input: s, expected: O.FileUtil.getFileExt(s),
        })),
        filenameNoExt: ["a.b.c", "untitled", ".hidden", "a"].map((s) => ({
            input: s, expected: O.FileUtil.getFilenameNoExt(s),
        })),
        filenameWithExt: ["OPX:x", "PNG:thumb", "CP:a.b"].map((s) => {
            const parts = s.split(":");
            return { fileType: parts[0], name: parts[1], expected: O.FileUtil.getFilenameWithExt(O.FileType.valueOf(parts[0]), parts[1]) };
        }),
        mimeType: ["png", "svg", "opx", "opxc", "cp", "unknown", "PNG"].map((s) => ({
            input: s, expected: O.FileUtil.getMimeType(s),
        })),
    };

    const cps = [
        dumpCpCase("segmentedSquare", buildCreasePatternSegmented()),
        dumpCpCase("mixedTypes", buildCreasePatternMixed()),
        dumpCpCase("small", buildFileSmall()),
    ];

    // force load (internal OPXC with no extension) + sniffed CP text
    const forceBase = buildCreasePatternSegmented();
    const forceBytes = O.io.exportOpxc(forceBase);
    const forceLoaded = new O.CreasePattern();
    O.io.loadCreasePatternForce("untitled", { name: "untitled", path: "project_data/untitled", bytes: forceBytes }, forceLoaded);
    const sniffBytes = O.io.exportCp(forceBase);
    const sniffLoaded = new O.CreasePattern();
    O.io.loadCreasePatternForce("scratch", { bytes: sniffBytes }, sniffLoaded);

    // OPX loader tolerance (omitted zero attributes / missing type)
    const tolerateXml = "<?xml version='1.0'?><java><object class=\"oripa.DataSet\"><void method=\"getField\">" +
        "<string>lines</string><void method=\"set\"><object idref=\"DataSet0\"/>" +
        "<array class=\"oripa.OriLineProxy\" length=\"1\">" +
        "<void index=\"0\"><object class=\"oripa.OriLineProxy\">" +
        "<void property=\"x1\"><double>10.0</double></void>" +
        "<void property=\"y0\"><double>-5.5</double></void>" +
        "</object></void></array></void></void></object></java>";
    const tolerateCp = new O.CreasePattern();
    O.io.loadCreasePattern("x.opx", { bytes: O.io.textToBytes(tolerateXml) }, tolerateCp);

    // LoaderOpxcToGL
    const toGLbytes = O.io.exportOpxc(buildCreasePatternSegmented());
    const positions = [];
    const types = [];
    const minMax = new O.MinMaxFloat();
    O.LoaderOpxcToGL.getCreasePattern({ bytes: toGLbytes }, positions, types, minMax);
    const emptyPositions = [];
    const emptyTypes = [];
    const emptyMinMax = new O.MinMaxFloat();
    O.LoaderOpxcToGL.getCreasePattern({ bytes: O.io.textToBytes("<data version=\"1.0\" paperSize=\"400\"></data>") },
        emptyPositions, emptyTypes, emptyMinMax);

    return {
        doubleToString: doubleCases,
        fileUtil: fileUtil,
        cpCases: cps,
        forceLoad: {
            opxc: text(forceBytes),
            expectedLines: linesOf(forceLoaded),
            sniffedCp: text(sniffBytes),
            sniffedExpectedLines: linesOf(sniffLoaded),
        },
        opxTolerate: { xml: tolerateXml, expectedLines: linesOf(tolerateCp) },
        malformed: [
            { fileType: "opxc", content: "<data><line x1=\"1\"", marker: "Error" },
            { fileType: "cp", content: "x 1 2 3 4", marker: "NumberFormatException" },
            { fileType: "opxc", content: "<data><line type=\"x\" x1=\"1\" y1=\"2\" x2=\"3\" y2=\"4\"/></data>", marker: "NumberFormatException" },
            { fileType: "cp", content: "999 0 0 1 1", marker: "NumberFormatException" },
            { fileType: "xyz", content: "anything", marker: "unsupported crease pattern file type" },
        ],
        loaderOpxcToGL: {
            positions: arr(positions),
            types: arr(types),
            minMax: { minX: bn(minMax.minX), minY: bn(minMax.minY), maxX: bn(minMax.maxX), maxY: bn(minMax.maxY) },
            emptyPositions: arr(emptyPositions),
            emptyTypes: arr(emptyTypes),
            emptyMinMax: {
                minX: bn(emptyMinMax.minX), minY: bn(emptyMinMax.minY),
                maxX: bn(emptyMinMax.maxX), maxY: bn(emptyMinMax.maxY),
            },
        },
    };
}

/* --------------------------------------------------------------- renderdata */
function dumpRenderDataForCp(name, cp) {
    const lines = Array.from(cp.lineMVFB);
    const points = Array.from(cp.pointMVFB);
    const flat = cp.isFlatFoldable();
    const polygons = flat ? Array.from(cp.facesCheck) : [];
    const typed = (z, z2) => {
        const d = O.GLDataCpLinesTyped.getRenderData(lines, z, z2);
        return { lineArray: arr(d.lineArray), typeArray: arr(d.typeArray) };
    };
    const typedWidth = (z, z2) => O.GLDataCpLinesTypedWidth.getRenderDataSplit(lines, z, z2).map((d) => ({
        vertexPosition: arr(d.vertexPosition),
        vertexAngleDeg: arr(d.vertexAngleDeg),
        lineDistance: arr(d.lineDistance),
        vertexType: arr(d.vertexType),
        drawOrder: arr(d.drawOrder),
    }));
    const linesWidth = (list) => {
        const d = O.GLDataLinesWidth.getRenderData(list);
        return {
            vertexPosition: arr(d.vertexPosition),
            vertexAngleDeg: arr(d.vertexAngleDeg),
            drawOrder: arr(d.drawOrder),
        };
    };
    const polys = O.GLDataCpPolygons.getRenderData(polygons);
    const previewBytes = O.io.exportOpxc(cp);
    const preview = O.GLDataCpPreview.getRenderData({ bytes: previewBytes });
    const blank = O.GLDataCpPreview.getRenderDataBlank();
    return {
        name: name,
        flatFoldable: flat,
        lineCount: lines.length,
        pointCount: points.length,
        lines: lines.map(lineDump),
        typed: {
            all: typed(false, false),
            mvb: typed(true, false),
            flatOnly: typed(false, true),
            both: typed(true, true),
        },
        typedWidth: {
            all: typedWidth(true, true),
            mvb: typedWidth(true, false),
            flatOnly: typedWidth(false, true),
        },
        linesWidth: {
            all: linesWidth(lines),
            single: lines.length > 0 ? linesWidth(lines[0]) : linesWidth(null),
            split: O.GLDataLinesWidth.getRenderDataSplit(lines).map((d) => ({
                vertexPosition: arr(d.vertexPosition),
                vertexAngleDeg: arr(d.vertexAngleDeg),
                drawOrder: arr(d.drawOrder),
            })),
        },
        polygons: { pointArray: arr(polys.pointArray), drawOrderArray: arr(polys.drawOrderArray) },
        simple: {
            linesToFloats: arr(O.GLDataCpSimple.linesToFloats(lines)),
            pointsToFloatsSimple: arr(O.GLDataCpSimple.pointsToFloatsSimple(points)),
            pointsFilteredBoth: arr(O.GLDataCpSimple.pointsToFloats(points, true, true)),
            pointsFilteredNone: arr(O.GLDataCpSimple.pointsToFloats(points, false, false)),
        },
        preview: {
            linePosition: arr(preview.linePosition),
            lineType: arr(preview.lineType),
            minMax: {
                minX: bn(preview.minMax.minX), minY: bn(preview.minMax.minY),
                maxX: bn(preview.minMax.maxX), maxY: bn(preview.minMax.maxY),
            },
            blank: {
                linePosition: arr(blank.linePosition),
                lineType: arr(blank.lineType),
                minMax: {
                    minX: bn(blank.minMax.minX), minY: bn(blank.minMax.minY),
                    maxX: bn(blank.minMax.maxX), maxY: bn(blank.minMax.maxY),
                },
            },
        },
    };
}

function buildRenderData() {
    const segmented = buildCreasePatternSegmented();
    const halfFold = loadCase("fold_in_half.cp");
    return {
        cps: [
            dumpRenderDataForCp("segmentedSquare", segmented),
            dumpRenderDataForCp("foldInHalf", halfFold),
        ],
    };
}

/* --------------------------------------------------------------------- main */
function copyCases() {
    fs.mkdirSync(CASES_DIR, { recursive: true });
    for (const name of fs.readdirSync(SRC_CASES)) {
        fs.copyFileSync(path.join(SRC_CASES, name), path.join(CASES_DIR, name));
    }
}

function writeJson(name, value) {
    const target = path.join(OUT_DIR, name);
    fs.writeFileSync(target, JSON.stringify(value, null, 1) + "\n");
    const size = fs.statSync(target).size;
    console.log("wrote " + path.relative(ROOT, target) + " (" + (size / 1024).toFixed(1) + " KiB)");
}

function main() {
    fs.mkdirSync(OUT_DIR, { recursive: true });
    copyCases();
    const roundtrip = buildRoundtrip();
    writeJson("roundtrip.json", roundtrip);
    const cases = buildCases();
    writeJson("cases.json", cases);
    const engine = buildEngine();
    writeJson("engine.json", engine);
    const renderdata = buildRenderData();
    writeJson("renderdata.json", renderdata);
    console.log("done");
}

main();

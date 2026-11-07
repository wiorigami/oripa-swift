#!/usr/bin/env node
/* Golden fixtures for ORIPA geometry (util/*.js): PointDouble, Segment, MinMax*,
 * GeomUtil, GLUtil, ColorUtil, DisplayUtil and the Java/JS rounding helpers. */
"use strict";
const fs = require("fs");
const path = require("path");
const O = require("../load_oripa.js")();
const G = O.GeomUtil;
const GL = O.GLUtil;
const OUT = path.resolve(__dirname, "../../../Fixtures/core");

const calls = [];
function call(fn, args, expected) { calls.push({ fn: fn, args: args, expected: expected }); }
function b(value) { return value ? 1 : 0; }
function pointOrEmpty(p) { return p === null || p === undefined ? [] : [p.x, p.y]; }
const P = O.PointDouble;

/* ---- distances / angles ---- */
call("getDistance", [0, 0, 3, 4], [G.getDistance(0, 0, 3, 4)]);
call("getDistance", [-10, 5, 7, -3], [G.getDistance(-10, 5, 7, -3)]);
call("getDistanceSquared", [0, 0, 3, 4], [G.getDistanceSquared(0, 0, 3, 4)]);
call("getDistanceSquared", [1, 2, 4, 6], [G.getDistanceSquared(1, 2, 4, 6)]);
call("getAngleRadians", [0, 0, 1, 1], [G.getAngleRadians(0, 0, 1, 1)]);
call("getAngleRadians", [0, 0, -1, 0], [G.getAngleRadians(0, 0, -1, 0)]);
call("getAngleRadBetweenLines", [0, 0, 1, 0, 0, 0, 0, 1], [G.getAngleRadBetweenLines(0, 0, 1, 0, 0, 0, 0, 1)]);
call("getAngleRadBetweenLines", [0, 0, 1, 0, 0, 0, 1, 1], [G.getAngleRadBetweenLines(0, 0, 1, 0, 0, 0, 1, 1)]);
call("getDotProductLines2D", [0, 0, 1, 0, 0, 0, 0, 1], [G.getDotProductLines2D(0, 0, 1, 0, 0, 0, 0, 1)]);

/* ---- intersections ---- */
call("getLineIntersect", [0, 0, 10, 0, 5, -5, 5, 5], pointOrEmpty(G.getLineIntersect(0, 0, 10, 0, 5, -5, 5, 5)));
call("getLineIntersect", [0, 0, 1, 0, 0, 1, 1, 1], pointOrEmpty(G.getLineIntersect(0, 0, 1, 0, 0, 1, 1, 1)));
call("getLineIntersect", [0, 0, 0, 10, 5, 0, 5, 10], pointOrEmpty(G.getLineIntersect(0, 0, 0, 10, 5, 0, 5, 10)));
call("getLineIntersect", [-3, -3, 4, 2, -2, 4, 5, -4], pointOrEmpty(G.getLineIntersect(-3, -3, 4, 2, -2, 4, 5, -4)));
call("getSegmentIntersect", [0, 0, 10, 0, 5, -5, 5, 5], pointOrEmpty(G.getSegmentIntersect(0, 0, 10, 0, 5, -5, 5, 5)));
call("getSegmentIntersect", [0, 0, 1, 0, 5, -5, 5, 5], pointOrEmpty(G.getSegmentIntersect(0, 0, 1, 0, 5, -5, 5, 5)));
call("getSegmentIntersect", [0, 0, 10, 0, 5, 0, 5, 10], pointOrEmpty(G.getSegmentIntersect(0, 0, 10, 0, 5, 0, 5, 10)));
call("getSegmentIntersect", [0, 0, 10, 10, 10, 0, 20, 10], pointOrEmpty(G.getSegmentIntersect(0, 0, 10, 10, 10, 0, 20, 10)));

/* ---- predicates ---- */
call("isParallel", [0, 0, 1, 0, 0, 1, 1, 1], [b(G.isParallel(0, 0, 1, 0, 0, 1, 1, 1))]);
call("isParallel", [0, 0, 1, 0, 0, 1, 0, 2], [b(G.isParallel(0, 0, 1, 0, 0, 1, 0, 2))]);
call("isCollinear", [0, 0, 1, 1, 2, 2, 3, 3], [b(G.isCollinear(0, 0, 1, 1, 2, 2, 3, 3))]);
call("isCollinear", [0, 0, 1, 1, 2, 2, 4, 3], [b(G.isCollinear(0, 0, 1, 1, 2, 2, 4, 3))]);
call("getDistanceBetweenParallel", [0, 0, 1, 0, 0, 3, 1, 3], [G.getDistanceBetweenParallel(0, 0, 1, 0, 0, 3, 1, 3)]);
call("getPerpendicularDistance", [0, 0, 10, 0, 5, 4], [G.getPerpendicularDistance(0, 0, 10, 0, 5, 4)]);
call("getPerpendicularDistance", [0, 0, 0, 10, 4, 5], [G.getPerpendicularDistance(0, 0, 0, 10, 4, 5)]);
call("getPerpendicularIntersect", [0, 0, 10, 0, 3, 7], pointOrEmpty(G.getPerpendicularIntersect(0, 0, 10, 0, 3, 7)));
call("getPerpendicularIntersect", [0, 0, 0, 10, 3, 7], pointOrEmpty(G.getPerpendicularIntersect(0, 0, 0, 10, 3, 7)));

/* ---- ranges / clamps ---- */
call("isInRange", [0, 10, 5], [b(G.isInRange(0, 10, 5))]);
call("isInRange", [0, 10, 11], [b(G.isInRange(0, 10, 11))]);
call("isInRange", [10, 0, -0.0004], [b(G.isInRange(10, 0, -0.0004))]);
call("isInRangePoint", [0, 0, 10, 10, 5, 5], [b(G.isInRange(new P(0, 0), new P(10, 10), new P(5, 5)))]);
call("isInRangePoint", [0, 0, 10, 10, 5, 12], [b(G.isInRange(new P(0, 0), new P(10, 10), new P(5, 12)))]);
call("isInRangeInt", [0, 10, 10], [b(G.isInRangeInt(0, 10, 10))]);
call("isInRangeInt", [0, 10, 11], [b(G.isInRangeInt(0, 10, 11))]);
call("clamp", [-1, 4], [G.clamp(-1, 4)]);
call("clamp", [4, 4], [G.clamp(4, 4)]);
call("clamp", [6, 4], [G.clamp(6, 4)]);
call("clamp", [0, 4], [G.clamp(0, 4)]);
call("constrain", [11, 0, 10], [G.constrain(11, 0, 10)]);
call("constrain", [-1, 0, 10], [G.constrain(-1, 0, 10)]);
call("constrain", [5, 0, 10], [G.constrain(5, 0, 10)]);

/* ---- polygons ---- */
call("getDeterminant3x3", [1, 0, 0, 0, 1, 0, 0, 0, 1], [G.getDeterminant3x3([1, 0, 0, 0, 1, 0, 0, 0, 1])]);
call("getDeterminant3x3", [1, 2, 3, 4, 5, 6, 7, 8, 9], [G.getDeterminant3x3([1, 2, 3, 4, 5, 6, 7, 8, 9])]);
call("isCCW", [0, 0, 1, 0, 0, 1], [b(G.isCCW(new P(0, 0), new P(1, 0), new P(0, 1)))]);
call("isCCW", [0, 0, 0, 1, 1, 0], [b(G.isCCW(new P(0, 0), new P(0, 1), new P(1, 0)))]);
call("getIncenter", [0, 0, 6, 0, 3, 4], pointOrEmpty(G.getIncenter(new P(0, 0), new P(6, 0), new P(3, 4))));
call("getIncenter", [0, 0, 10, 0, 0, 10], pointOrEmpty(G.getIncenter(new P(0, 0), new P(10, 0), new P(0, 10))));
call("getPolygonArea", [0, 0, 10, 0, 10, 10, 0, 10], [G.getPolygonArea([new P(0, 0), new P(10, 0), new P(10, 10), new P(0, 10)])]);
call("getPolygonArea", [0, 0, 3, 0, 0, 4], [G.getPolygonArea([new P(0, 0), new P(3, 0), new P(0, 4)])]);
call("isPointInOriginSquare", [0, 0, 100, 0], [b(G.isPointInOriginSquare(new P(0, 0), 100, 0))]);
call("isPointInOriginSquare", [200, 0, 100, 0], [b(G.isPointInOriginSquare(new P(200, 0), 100, 0))]);
call("isPointInOriginRectangle", [50, 40, 100, 50, 0], [b(G.isPointInOriginRectangle(new P(50, 40), 100, 50, 0))]);
call("isPointInOriginRectangle", [50, 70, 100, 50, 0], [b(G.isPointInOriginRectangle(new P(50, 70), 100, 50, 0))]);
call("isPointOutsideOriginSquare", [150, 0, 100, 0], [b(G.isPointOutsideOriginSquare(new P(150, 0), 100, 0))]);
call("isPointOutsideOriginSquare", [50, 0, 100, 0], [b(G.isPointOutsideOriginSquare(new P(50, 0), 100, 0))]);
call("isPointOutsideOriginRectangle", [50, 70, 100, 50, 0], [b(G.isPointOutsideOriginRectangle(new P(50, 70), 100, 50, 0))]);
call("isPointInOriginHexagon", [0, 0, 100, 0], [b(G.isPointInOriginHexagon(new P(0, 0), 100, 0))]);
call("isPointInOriginHexagon", [150, 0, 100, 0], [b(G.isPointInOriginHexagon(new P(150, 0), 100, 0))]);
call("isPointInOriginHexagon", [0, 120, 100, 0], [b(G.isPointInOriginHexagon(new P(0, 120), 100, 0))]);
call("getDefaultIntKey", [0.5], [G.getDefaultIntKey(0.5)]);
call("getDefaultIntKey", [-1.234567], [G.getDefaultIntKey(-1.234567)]);
call("getIntKey", [10, 0.55], [G.getIntKey(10, 0.55)]);

const convex = [new P(0, 0), new P(10, 0), new P(10, 10), new P(0, 10)];
call("isPointInConvexPolygon", [100000, 0, 5, 5, 100, 5], [b(G.isPointInConvexPolygon(100000, false, new P(5, 5), new P(100, 5), convex))]);
call("isPointInConvexPolygon", [100000, 0, 5, 5, 3, 3], [b(G.isPointInConvexPolygon(100000, false, new P(5, 5), new P(3, 3), convex))]);

const poly1 = [new P(0, 0), new P(10, 0), new P(10, 10), new P(0, 10)];
const poly2 = [new P(-5, 5), new P(5, 5), new P(5, 15), new P(-5, 15)];
const poly3 = [new P(20, 20), new P(30, 20), new P(30, 30), new P(20, 30)];
const polyCalls = [
    { z: 0, poly1: poly1, poly2: poly2, expected: G.doPolygonLinesCross(false, poly1, poly2) ? 1 : 0 },
    { z: 1, poly1: poly1, poly2: poly2, expected: G.doPolygonLinesCross(true, poly1, poly2) ? 1 : 0 },
    { z: 0, poly1: poly1, poly2: poly3, expected: G.doPolygonLinesCross(false, poly1, poly3) ? 1 : 0 },
].map(function (c) {
    return {
        z: c.z,
        poly1: c.poly1.map(function (p) { return [p.x, p.y]; }),
        poly2: c.poly2.map(function (p) { return [p.x, p.y]; }),
        expected: c.expected,
    };
});

/* ---- GLUtil matrices ---- */
const identity = new Array(16).fill(0);
GL.setIdentityM(identity, 0);
const translated = identity.slice();
GL.translateM(translated, 0, 10, 20, 0);
const rotate = new Array(16).fill(0);
GL.setIdentityM(rotate, 0);
GL.rotateM(rotate, 0, 90, 0, 0, 1);
const inverse = new Array(16).fill(0);
GL.invertM(inverse, 0, rotate, 0);
const product = new Array(16).fill(0);
GL.multiplyMM(product, 0, rotate, 0, inverse, 0);
const scaled = new Array(16).fill(0);
GL.setIdentityM(scaled, 0);
GL.scaleM(scaled, 0, 2, 3, 1);
const mirror = G.getMirrorTransformMatrix(new P(-100, 0), new P(100, 0));
const mirrorLine = G.getTransformedLine(new P(10, 20), new P(-30, 5), mirror);
const floatMatrix = Array.from(Float32Array.from(rotate));
const pTranslated = GL.getTransformedPointDouble(translated, 3, 4);
const pObject = GL.getObjectPointFromWorldPointDouble(translated, 13, 24);
const pObjectFloat = GL.getObjectPointFromWorldPointFloat(translated, 13, 24);
const pRotated = GL.getTransformedPointDouble(rotate, 1, 0);
const pScaled = GL.getTransformedPointDouble(scaled, 1, 1);
const pFloat = GL.getTransformedPointDouble(floatMatrix, Math.fround(1), Math.fround(0));

const mirrorBack = G.getTransformedLine(mirrorLine.start, mirrorLine.end, mirror);
const mirrorFixed = G.getTransformedLine(new P(0, 0), new P(50, 50), mirror);

const glutil = {
    MAX_FACE_SETS: GL.MAX_FACE_SETS,
    MAX_LINE_SETS: GL.MAX_LINE_SETS,
    MAX_LINES_PER_SET: GL.MAX_LINES_PER_SET,
    identity: identity,
    translated: translated,
    translatedPoint: [pTranslated.x, pTranslated.y],
    objectPoint: [pObject.x, pObject.y],
    objectPointFloat: [pObjectFloat.x, pObjectFloat.y],
    rotate90: rotate,
    rotatedPoint: [pRotated.x, pRotated.y],
    inverseRotate90: inverse,
    rotateTimesInverse: product,
    scaled: scaled,
    scaledPoint: [pScaled.x, pScaled.y],
    floatMatrixRotate90: floatMatrix,
    floatMatrixPoint: [pFloat.x, pFloat.y],
    mirrorMatrix: mirror,
    mirrorLine: [mirrorLine.start.x, mirrorLine.start.y, mirrorLine.end.x, mirrorLine.end.y],
    mirrorBack: [mirrorBack.start.x, mirrorBack.start.y, mirrorBack.end.x, mirrorBack.end.y],
    mirrorFixed: [mirrorFixed.start.x, mirrorFixed.start.y],
};

/* ---- PointDouble / Segment / MinMax ---- */
const pd = new P(3, 4);
const segment = new O.Segment(new P(0, 0), new P(10, 0));
const pointDouble = {
    length: pd.length(),
    staticLength: P.length(3, 4),
    hashCode: pd.hashCode(),
    hashCodes: [new P(0, 0).hashCode(), new P(1, 2).hashCode(), new P(-3.5, 7.25).hashCode()],
    equalsSame: pd.equals(new P(3, 4)) ? 1 : 0,
    equalsDifferent: pd.equals(new P(3, 5)) ? 1 : 0,
    minDistance: pd.getMinDistance(new P(0, 0)),
    toString: pd.toString(),
};
const segmentData = {
    hashCode: segment.hashCode(),
    equalsSame: segment.equals(new O.Segment(new P(0, 0), new P(10, 0))) ? 1 : 0,
    equalsReversed: segment.equals(new O.Segment(new P(10, 0), new P(0, 0))) ? 1 : 0,
    minDistancePerpendicular: segment.getMinDistance(new P(5, 3)),
    minDistanceEndpoint: segment.getMinDistance(new P(-2, 0)),
    minDistances: [
        segment.getMinDistance(new P(5, 3)),
        segment.getMinDistance(new P(-2, 0)),
        segment.getMinDistance(new P(12, 0)),
        segment.getMinDistance(new P(5, -7)),
    ],
};
const minMaxDouble = {
    empty: new O.MinMaxDouble().toArray(),
    custom: new O.MinMaxDouble(1, 2, 3, 4).toArray(),
    readArray: O.MinMaxDouble.readArray([-1, -2, 5, 6]).toArray(),
    centers: [
        new O.MinMaxDouble(0, 0, 10, 20).getCenterX(),
        new O.MinMaxDouble(0, 0, 10, 20).getCenterY(),
        new O.MinMaxDouble(0, 0, 10, 20).getHalfSizeX(),
        new O.MinMaxDouble(0, 0, 10, 20).getHalfSizeY(),
        new O.MinMaxDouble(0, 0, 10, 20).getMaxHalfSize(),
    ],
};
const minMaxFloat = {
    empty: new O.MinMaxFloat().toArray(),
    readArray: O.MinMaxFloat.readArray([-1.5, -2.5, 5.5, 6.5]).toArray(),
    centers: [
        new O.MinMaxFloat(0, 0, 10, 20).getCenterX(),
        new O.MinMaxFloat(0, 0, 10, 20).getCenterY(),
        new O.MinMaxFloat(0, 0, 10, 20).getHalfSizeX(),
        new O.MinMaxFloat(0, 0, 10, 20).getMaxHalfSize(),
    ],
};

/* ---- ColorUtil / DisplayUtil / JS rounding ---- */
const rgbFloat = O.ColorUtil.getRgbFloatFromInt(0xFF8000);
const colorUtil = {
    rainbow: O.ColorUtil.getRainbow(),
    intToStringRgb: [-65536, 0x123456, 0, -1, 0x00ABCDEF].map(function (v) { return O.ColorUtil.intToStringRgb(v); }),
    intToStringRgbNoHash: [0x123456, -65536].map(function (v) { return O.ColorUtil.intToStringRgbNoHash(v); }),
    rgbFloat: [Math.fround(rgbFloat[0]), Math.fround(rgbFloat[1]), Math.fround(rgbFloat[2])],
    hueAngleDeg: [0xFF0000, 0x00FF00, 0x0000FF, 0xFFFFFF, 0x000000].map(function (v) { return O.ColorUtil.getHueAngleDeg(v); }),
    saturatedHue: [0, 120, 240, 60, 300].map(function (v) { return O.ColorUtil.getSaturatedHue(v); }),
};
const displayUtil = {
    pixelFromDp: [O.DisplayUtil.getPixelFromDp(16), O.DisplayUtil.getPixelFromDp(2, 16), O.DisplayUtil.getPixelFromDp(3, 5)],
    gridColumnCount: [
        O.DisplayUtil.getGridColumnCount(320, 100),
        O.DisplayUtil.getGridColumnCount(768, 2, 100),
        O.DisplayUtil.getGridColumnCount(100, 300),
    ],
};
const jsRound = [1.2344, 1.2345, 1.2346, -1.2345, -2.5, -0.5, 0.5, 2.5, 1234.5678].map(function (v) {
    return { value: v, round: Math.round(v), roundTimes1000: Math.round(v * 1000) };
});

const data = {
    calls: calls,
    polygonCalls: polyCalls,
    glutil: glutil,
    pointDouble: pointDouble,
    segment: segmentData,
    minMaxDouble: minMaxDouble,
    minMaxFloat: minMaxFloat,
    colorUtil: colorUtil,
    displayUtil: displayUtil,
    jsRound: jsRound,
};

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "geom.json"), JSON.stringify(data, null, 1) + "\n");
console.log("wrote Fixtures/core/geom.json (" + calls.length + " calls)");

#!/usr/bin/env node
/* Golden fixtures for the crease-pattern entity types + grid:
 * OriPoint, OriLine, OriPolygon, GridManager/Square+Triangle grids. */
"use strict";
const fs = require("fs");
const path = require("path");
const O = require("../load_oripa.js")();
const OUT = path.resolve(__dirname, "../../../Fixtures/core");

function pt(x, y) { return new O.OriPoint(x, y); }
function ptd(x, y) { return new O.PointDouble(x, y); }
function line(x1, y1, x2, y2, t) { return new O.OriLine(pt(x1, y1), pt(x2, y2), t === undefined ? 2 : t); }
function lineArr(l) {
    return [l.start.x, l.start.y, l.end.x, l.end.y, l.type()];
}
function nearestPointData(nearest) {
    return {
        point: nearest.nearestItem === null || nearest.nearestItem === undefined ? null : [nearest.nearestItem.x, nearest.nearestItem.y],
        distance: nearest.distance,
    };
}
function nearestLineData(nearest) {
    const item = nearest.nearestItem;
    return {
        line: item === null || item === undefined ? null : [item.start.x, item.start.y, item.end.x, item.end.y, item.type()],
        distance: nearest.distance,
    };
}
function triesInt(fn) { try { return fn() ? 1 : 0; } catch (e) { return -1; } }

/* ---- OriPoint ---- */
const getKeyCases = [1.2344, 1.2345, 1.2346, -1.2345, -7.89012, 0.0, 200.0, -0.0004, 0.0005, 1234.5678].map(function (d) {
    return { value: d, key: O.OriPoint.getKey(d) };
});
const pointSpecs = [
    [1.23456, -7.89012],
    [0, 0],
    [-200, 200],
    [100, 100.0004],
    [0.0004, -0.0004],
];
const points = pointSpecs.map(function (spec) {
    const p = pt(spec[0], spec[1]);
    const copy = p.copy();
    return {
        x: spec[0], y: spec[1],
        xKey: p.xKey, yKey: p.yKey,
        hash: p.hashCode(),
        equalsEqual: p.equals(pt(spec[0], spec[1])) ? 1 : 0,
        equalsDifferent: p.equals(pt(spec[0] + 100, spec[1])) ? 1 : 0,
        copyEquals: copy.equals(p) ? 1 : 0,
        copyIsSameObject: copy === p ? 1 : 0,
        occurrenceCount: p.getOccurrenceCount(),
        lineTypeCount: p.getAllLineTypeCount().slice(0, 4),
        floatArray: [p.x, p.y].map(Math.fround),
        pointDoubleHash: ptd(spec[0], spec[1]).hashCode(),
    };
});
const compareCases = [];
const comparePoints = [[0, 0], [0, 1], [0, -1], [1, 0], [-1, 0], [1.0004, 0], [1, 2], [2, 1]];
for (const a of comparePoints) {
    for (const b of comparePoints) {
        compareCases.push({ a: a, b: b, result: pt(a[0], a[1]).compareTo(pt(b[0], b[1])) });
    }
}

/* ---- OriLine ---- */
const lineSpecs = [
    { start: [100, 0], end: [0, 0], type: 2 },
    { start: [0, 0], end: [100, 100], type: 3 },
    { start: [50, 50], end: [-50, -50], type: 1 },
    { start: [0, 100], end: [100, 0], type: 0 },
];
const lines = lineSpecs.map(function (spec) {
    const l = line(spec.start[0], spec.start[1], spec.end[0], spec.end[1], spec.type);
    const copied = l.copy();
    const diagonal = l.diagonalCopy();
    return {
        input: [spec.start[0], spec.start[1], spec.end[0], spec.end[1], spec.type],
        ordered: lineArr(l),
        type: l.type(),
        hash: l.hashCode(),
        floatArray: l.toFloatArray().map(Math.fround),
        copyEquals: copied.equals(l) ? 1 : 0,
        copyIsSameObject: copied === l ? 1 : 0,
        copyPointsDistinct: (copied.start !== l.start && copied.end !== l.end) ? 1 : 0,
        diagonalStart: [diagonal.start.x, diagonal.start.y],
        diagonalEnd: [diagonal.end.x, diagonal.end.y],
        diagonalOrdered: lineArr(diagonal),
        reversedConstructorEquals: line(spec.end[0], spec.end[1], spec.start[0], spec.start[1], spec.type).equals(l) ? 1 : 0,
        noSortInput: (function () {
            const unsorted = new O.OriLine(pt(spec.start[0], spec.start[1]), pt(spec.end[0], spec.end[1]), spec.type, true);
            return [unsorted.start.x, unsorted.start.y, unsorted.end.x, unsorted.end.y];
        })(),
    };
});
const containsInRange = [];
const horizontal = line(0, 0, 100, 0, 2);
for (const p of [[50, 0], [0, 0], [100, 0], [150, 0], [50, 10], [-1, 0]]) {
    containsInRange.push({ point: p, result: horizontal.containsInRange(pt(p[0], p[1])) ? 1 : 0 });
}
const setTypeLine = line(0, 0, 100, 0, 2);
const startPoint = setTypeLine.start;
setTypeLine.setType(3);
const lineTypeChange = {
    type: setTypeLine.type(),
    startMountain: startPoint.getLineTypeCount(2),
    startValley: startPoint.getLineTypeCount(3),
};

/* ---- OriPolygon ---- */
const polygonSpecs = [
    { points: [[0, 0], [10, 0], [10, 10], [0, 10]], lineTypes: [1, 1, 1, 1] },
    { points: [[0, 0], [3, 0], [0, 4]], lineTypes: [2, 3, 1] },
    { points: [[-10, -10], [10, -10], [10, 10], [-10, 10]], lineTypes: [2, 3, 2, 3] },
];
const polygons = polygonSpecs.map(function (spec) {
    const polygon = new O.OriPolygon();
    for (let i = 0; i < spec.points.length; i++) {
        polygon.points.push(pt(spec.points[i][0], spec.points[i][1]));
        polygon.lineTypes.push(spec.lineTypes[i]);
    }
    const centroid = polygon.getCentroid();
    return {
        points: spec.points,
        lineTypes: spec.lineTypes,
        area: polygon.getArea(),
        centroid: [centroid.x, centroid.y],
    };
});

/* ---- GridManager ---- */
function gridSnapshot(manager) {
    return {
        division: manager.getDivisionNumber(),
        renderData: {
            vertexPosition: manager.getRenderData().vertexPosition.map(Math.fround),
            vertexAngleDeg: manager.getRenderData().vertexAngleDeg,
            drawOrder: manager.getRenderData().drawOrder,
        },
    };
}
const gridQueries = {
    square: (function () {
        const manager = new O.GridManager(200);
        const queries = [
            { point: [104, 104], radius: 10 },
            { point: [5, 5], radius: 1 },
            { point: [-300, 0], radius: 10 },
            { point: [199, -199], radius: 4 },
            { point: [-100.4, 100.4], radius: 1 },
        ];
        return {
            defaultDivision: 4,
            defaultGridType: 0,
            findPoints: queries.map(function (q) {
                return { point: q.point, radius: q.radius, result: nearestPointData(manager.findPoint(ptd(q.point[0], q.point[1]), q.radius)) };
            }),
            lineQueries: [
                { point: [99, 2], radius: 5 },
                { point: [0, 0], radius: 1 },
                { point: [103, 0], radius: 5 },
                { point: [300, 0], radius: 5 },
            ].map(function (q) {
                return { point: q.point, radius: q.radius, result: nearestLineData(manager.findLine(ptd(q.point[0], q.point[1]), q.radius)) };
            }),
            updates: [
                { division: 8, type: 0, result: manager.update(8, 0) ? 1 : 0 },
                { division: 8, type: 0, result: manager.update(8, 0) ? 1 : 0 },
                { division: 4, type: 1, result: manager.update(4, 1) ? 1 : 0 },
                { division: 3, type: 1, result: manager.update(3, 1) ? 1 : 0 },
                { division: 2, type: 0, result: manager.update(2, 0) ? 1 : 0 },
                { division: 0, type: 0, result: triesInt(function () { return manager.update(0, 0); }) },
                { division: 4, type: 127, result: triesInt(function () { return manager.update(4, 127); }) },
            ],
        };
    })(),
    squareRenderData4: (function () {
        const manager = new O.GridManager(200);
        const data = manager.getRenderData();
        return {
            vertexPosition: data.vertexPosition.map(Math.fround),
            vertexAngleDeg: data.vertexAngleDeg,
            drawOrder: data.drawOrder,
        };
    })(),
    squareRenderData3: (function () {
        const manager = new O.GridManager(200);
        manager.update(3, 0);
        const data = manager.getRenderData();
        return {
            vertexPosition: data.vertexPosition.map(Math.fround),
            vertexAngleDeg: data.vertexAngleDeg,
            drawOrder: data.drawOrder,
        };
    })(),
    triangle: (function () {
        const manager = new O.GridManager(200);
        manager.update(4, 1);
        return {
            findPoints: [
                { point: [0, 0], radius: 10 },
                { point: [10, 10], radius: 3 },
                { point: [500, 0], radius: 5 },
            ].map(function (q) {
                return { point: q.point, radius: q.radius, result: nearestPointData(manager.findPoint(ptd(q.point[0], q.point[1]), q.radius)) };
            }),
            lineQueries: [
                { point: [0, 0], radius: 40 },
                { point: [100, 100], radius: 20 },
                { point: [0, 200], radius: 5 },
            ].map(function (q) {
                return { point: q.point, radius: q.radius, result: nearestLineData(manager.findLine(ptd(q.point[0], q.point[1]), q.radius)) };
            }),
        };
    })(),
    triangleRenderData3: (function () {
        const manager = new O.GridManager(200);
        manager.update(3, 1);
        const data = manager.getRenderData();
        return {
            vertexPosition: data.vertexPosition.map(Math.fround),
            vertexAngleDeg: data.vertexAngleDeg,
            drawOrder: data.drawOrder,
        };
    })(),
};

const data = {
    getKeyCases: getKeyCases,
    points: points,
    compareCases: compareCases,
    lines: lines,
    containsInRange: containsInRange,
    lineTypeChange: lineTypeChange,
    polygons: polygons,
    grid: gridQueries,
};

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "model.json"), JSON.stringify(data, null, 1) + "\n");
console.log("wrote Fixtures/core/model.json");

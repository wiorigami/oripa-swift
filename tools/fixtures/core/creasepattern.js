#!/usr/bin/env node
/* Golden fixtures for CreasePattern + HistoryManager (model/creasepattern/CreasePattern.js,
 * model/history/*.js): defaults, default square, duplicate rejection, nearest queries, grid
 * snapping, type changes, orphan-point cleanup, cleanStraightLines, flat-foldability, undo/redo. */
"use strict";
const fs = require("fs");
const path = require("path");
const O = require("../load_oripa.js")();
const OUT = path.resolve(__dirname, "../../../Fixtures/core");

function pt(x, y) { return new O.OriPoint(x, y); }
function ptd(x, y) { return new O.PointDouble(x, y); }
function line(x1, y1, x2, y2, t) { return new O.OriLine(pt(x1, y1), pt(x2, y2), t === undefined ? 2 : t); }
function lineArr(l) { return [l.start.x, l.start.y, l.end.x, l.end.y, l.type()]; }
function tries(fn) { try { fn(); return 0; } catch (e) { return 1; } }
function sortedLines(cp) {
    return cp.lineMVFB.getAllLines().values().map(lineArr).sort(function (a, b) {
        for (let i = 0; i < 4; i++) { if (a[i] !== b[i]) return a[i] - b[i]; }
        return a[4] - b[4];
    });
}
function sortedPoints(cp) {
    const result = [];
    const iterator = cp.pointMVFB.iterator();
    while (iterator.hasNext()) {
        const p = iterator.next();
        result.push([p.xKey, p.yKey, p.x, p.y]);
    }
    return result.sort(function (a, b) { return a[0] === b[0] ? a[1] - b[1] : a[0] - b[0]; });
}
function findPointLookup(cp, x, y) {
    const list = cp.pointMVFB.findAllPointsInRange(ptd(x - 1, y - 1), ptd(x + 1, y + 1)).values();
    return list.length > 0 ? [list[0].x, list[0].y] : null;
}
function cpPoint(p) { return p === null || p === undefined ? null : [p.x, p.y]; }
function cpLine(l) { return l === null || l === undefined ? null : lineArr(l); }
function nearestPoint(nearest) {
    return {
        point: nearest.nearestItem === null || nearest.nearestItem === undefined ? null : [nearest.nearestItem.x, nearest.nearestItem.y],
        distance: nearest.distance,
    };
}
function nearestLine(nearest) {
    const item = nearest.nearestItem;
    return {
        line: item === null || item === undefined ? null : [item.start.x, item.start.y, item.end.x, item.end.y, item.type()],
        distance: nearest.distance,
    };
}
function minMaxArray(minMax) { return [minMax.minX, minMax.minY, minMax.maxX, minMax.maxY]; }
function faceInvariants(cp) {
    const faces = cp.facesCheck.values();
    const areas = faces.map(function (face) { return face.getArea(); }).sort(function (a, b) { return a - b; });
    const pointCounts = faces.map(function (face) { return face.points.length; }).sort(function (a, b) { return a - b; });
    const typeCounts = faces.map(function (face) { return face.lineTypes.length; }).sort(function (a, b) { return a - b; });
    return {
        count: faces.length,
        areas: areas,
        pointCounts: pointCounts,
        typeCounts: typeCounts,
        areaSum: areas.reduce(function (acc, a) { return acc + a; }, 0.0),
    };
}
function errorPointKeys(cp) {
    return cp.pointErrorCheck.values().map(function (p) { return [p.xKey, p.yKey]; }).sort(function (a, b) {
        return a[0] === b[0] ? a[1] - b[1] : a[0] - b[0];
    });
}

/* 1. constructor defaults */
const defaults = (function () {
    const cp = new O.CreasePattern();
    const custom = new O.CreasePattern(50, 3);
    return {
        halfSize: cp.creasePatternHalfSize,
        inputLineType: cp.inputLineType,
        modified: cp.modified ? 1 : 0,
        lineCount: cp.lineMVFB.size(),
        pointCount: cp.pointMVFB.size(),
        facesCheckCount: cp.facesCheck.size(),
        pointErrorCheckCount: cp.pointErrorCheck.size(),
        minMax: minMaxArray(cp.minMaxCheck),
        gridRenderVertexCount: cp.grid.getRenderData().vertexPosition.length,
        hasUndo: cp.historyManager.hasUndo() ? 1 : 0,
        customHalfSize: custom.creasePatternHalfSize,
        customInputLineType: custom.inputLineType,
        customMinMax: minMaxArray(custom.minMaxCheck),
    };
})();

/* 2. default square */
const square = (function () {
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    return {
        lineCount: cp.lineMVFB.size(),
        pointCount: cp.pointMVFB.size(),
        lines: sortedLines(cp),
        points: sortedPoints(cp),
        minMax: minMaxArray(cp.minMaxCheck),
        findPointCenter: cpPoint(cp.findPoint(false, ptd(0, 0), 300)),
        findLineEdge: cpLine(cp.findLine(false, ptd(250, 0), 100)),
    };
})();

/* 3. add / duplicate / diagonal duplicate / degenerate rejection */
const addReject = (function () {
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    const before = cp.lineMVFB.size();
    const afterAdd = cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    const countAfterAdd = cp.lineMVFB.size();
    const pointCountAfterAdd = cp.pointMVFB.size();
    cp.addLineCheckNoException(line(100, 0, 0, 0, 3));
    const countAfterDuplicate = cp.lineMVFB.size();
    cp.addLineCheckNoException(line(0, 0, 100, 100, 2));
    const countAfterDiagonal = cp.lineMVFB.size();
    cp.addLineCheckNoException(line(0, 100, 100, 0, 2));
    const countAfterDiagonalDuplicate = cp.lineMVFB.size();
    cp.addLineCheckNoException(line(5, 5, 5, 5, 2));
    const countAfterDegenerate = cp.lineMVFB.size();
    const pointCountAfterDegenerate = cp.pointMVFB.size();
    return {
        before: before,
        afterAddReturn: afterAdd ? 1 : 0,
        countAfterAdd: countAfterAdd,
        pointCountAfterAdd: pointCountAfterAdd,
        countAfterDuplicate: countAfterDuplicate,
        countAfterDiagonal: countAfterDiagonal,
        countAfterDiagonalDuplicate: countAfterDiagonalDuplicate,
        countAfterDegenerate: countAfterDegenerate,
        pointCountAfterDegenerate: pointCountAfterDegenerate,
    };
})();

/* 4. nearest point/line queries with and without grid snapping */
const findQueries = (function () {
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    return {
        pointNoSnapNearest: cpPoint(cp.findPoint(false, ptd(3, 3), 10)),
        pointNoSnapMiss: cpPoint(cp.findPoint(false, ptd(3, 3), 2)),
        pointWithSnap: cpPoint(cp.findPoint(true, ptd(3, 3), 10)),
        lineNoSnapNearest: cpLine(cp.findLine(false, ptd(50, 2), 10)),
        lineNoSnapMiss: cpLine(cp.findLine(false, ptd(50, 50), 3)),
        lineWithGridNearest: cpLine(cp.findLine(true, ptd(99, 2), 5)),
    };
})();

/* 5. changeLineType (+ error path) */
const changeType = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    const stored = cp.lineMVFB.findExact(line(0, 0, 100, 0, 2));
    cp.changeLineType(stored, 3);
    const startPoint = findPointLookup(cp, 0, 0);
    const counts = (function () {
        const list = cp.pointMVFB.findAllPointsInRange(ptd(-1, -1), ptd(1, 1)).values();
        const p = list[0];
        return [p.getLineTypeCount(0), p.getLineTypeCount(1), p.getLineTypeCount(2), p.getLineTypeCount(3)];
    })();
    return {
        typeAfter: stored.type(),
        startCounts: counts,
        startPoint: startPoint,
        errorThrows: tries(function () { cp.changeLineType(line(0, 0, 50, 0, 2), 3); }),
    };
})();

/* 6. removeLine removes orphan points */
const removeOrphan = (function () {
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    const added = cp.lineMVFB.findExact(line(0, 0, 100, 0, 2));
    cp.removeLine(added);
    return {
        lineCount: cp.lineMVFB.size(),
        pointCount: cp.pointMVFB.size(),
        containsOldPoint: cp.pointMVFB.contains(pt(0, 0)) ? 1 : 0,
        containsOldEndpoint: cp.pointMVFB.contains(pt(100, 0)) ? 1 : 0,
        containsSquareCorner: cp.pointMVFB.contains(pt(200, 200)) ? 1 : 0,
    };
})();

/* 7. cleanStraightLines merges collinear pairs */
const cleanStraight = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 50, 0, 2));
    cp.addLineCheckNoException(line(50, 0, 100, 0, 2));
    const linesBefore = cp.lineMVFB.size();
    const middle = cp.pointMVFB.findAllPointsInRange(ptd(49, -1), ptd(51, 1)).values()[0];
    const points = new O.JavaSet();
    points.add(middle);
    const historyItems = cp.cleanStraightLines(points);
    const merged = cp.lineMVFB.getAllLines().values()[0];
    const pointsAfter = cp.pointMVFB.size();
    return {
        linesBefore: linesBefore,
        lineCount: cp.lineMVFB.size(),
        historyItemCount: historyItems.length,
        oldLineCount: historyItems.length > 0 ? historyItems[0].oldLines.length : -1,
        newLineCount: historyItems.length > 0 ? historyItems[0].newLines.length : -1,
        mergedStartX: Math.min(merged.start.x, merged.end.x),
        mergedEndX: Math.max(merged.start.x, merged.end.x),
        pointCount: pointsAfter,
        middleGone: cp.pointMVFB.contains(pt(50, 0)) ? 0 : 1,
        hasUndo: cp.historyManager.hasUndo() ? 1 : 0,
    };
})();

function makeCreasedSquare(types) {
    // Same construction as the reference JS test: AddSegmentSM.addNewLine splits the boundary
    // lines where the new crease endpoints land on them.
    const cp = new O.CreasePattern();
    cp.initializeDefaultSquare();
    const helper = new O.AddSegmentSM(false);
    const targets = [[200, 0], [0, 200], [-200, 0], [0, -200]];
    for (let i = 0; i < targets.length; i++) {
        helper.addNewLine(cp, ptd(0, 0), ptd(targets[i][0], targets[i][1]), types[i]);
    }
    return cp;
}

/* 8. isFlatFoldable: valid 4-crease interior vertex */
const flatValid = (function () {
    const cp = makeCreasedSquare([3, 3, 3, 2]);
    const centerList = cp.pointMVFB.findAllPointsInRange(ptd(-1, -1), ptd(1, 1)).values();
    const center = centerList[0];
    const flat = cp.isFlatFoldable();
    return {
        flat: flat ? 1 : 0,
        lines: sortedLines(cp),
        pointCount: cp.pointMVFB.size(),
        pointErrorCount: cp.pointErrorCheck.size(),
        faceInvariants: faceInvariants(cp),
        centerCounts: [center.getLineTypeCount(0), center.getLineTypeCount(1), center.getLineTypeCount(2), center.getLineTypeCount(3)],
        minMax: minMaxArray(cp.minMaxCheck),
    };
})();

/* 9. isFlatFoldable: Maekawa violation detected */
const flatInvalid = (function () {
    const cp = makeCreasedSquare([2, 3, 3, 2]);
    const flat = cp.isFlatFoldable();
    const errorKeys = errorPointKeys(cp);
    const faceCount = cp.facesCheck.size();
    return {
        flat: flat ? 1 : 0,
        lines: sortedLines(cp),
        pointCount: cp.pointMVFB.size(),
        pointErrorCount: cp.pointErrorCheck.size(),
        errorPointKeys: errorKeys,
        faceCount: faceCount,
        clearCheckData: (function () {
            cp.clearCheckData();
            return { pointErrorCount: cp.pointErrorCheck.size(), faceCount: cp.facesCheck.size() };
        })(),
    };
})();

/* 10. clearAll */
const clearAll = (function () {
    const cp = makeCreasedSquare([3, 3, 3, 2]);
    cp.modified = true;
    cp.isFlatFoldable();
    cp.clearAll();
    return {
        lineCount: cp.lineMVFB.size(),
        pointCount: cp.pointMVFB.size(),
        faceCount: cp.facesCheck.size(),
        pointErrorCount: cp.pointErrorCheck.size(),
        hasUndo: cp.historyManager.hasUndo() ? 1 : 0,
        hasRedo: cp.historyManager.hasRedo() ? 1 : 0,
        lineTreeEmpty: cp.lineMVFB.isEmpty() ? 1 : 0,
        pointTreeEmpty: cp.pointMVFB.isEmpty() ? 1 : 0,
    };
})();

/* ---- history: undo / redo ---- */
function makeTwoLines() {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    cp.addLineCheckNoException(line(0, 100, 100, 100, 2));
    return cp;
}

const historyNewLine = (function () {
    const cp = makeTwoLines();
    const added = line(0, 0, 0, 100, 3);
    cp.addLineNoCheck(added);
    const item = new O.HistoryItem();
    item.newLines.push(added);
    const group = new O.HistoryGroup(0);
    group.add(item);
    cp.historyManager.newBranch(group);
    const afterAdd = cp.lineMVFB.size();
    const hasUndoAfterBranch = cp.historyManager.hasUndo() ? 1 : 0;
    const hasRedoAfterBranch = cp.historyManager.hasRedo() ? 1 : 0;
    cp.historyManager.undo(cp);
    const afterUndo = cp.lineMVFB.size();
    const undoEmpty = cp.historyManager.hasUndo() ? 1 : 0;
    const redoAvailable = cp.historyManager.hasRedo() ? 1 : 0;
    const pointCountAfterUndo = cp.pointMVFB.size();
    cp.historyManager.redo(cp);
    const afterRedo = cp.lineMVFB.size();
    const exactAfterRedo = cp.lineMVFB.findExact(line(0, 0, 0, 100, 3)) === null ? 0 : 1;
    const pointsAfterRedo = cp.pointMVFB.size();
    return {
        afterAdd: afterAdd,
        hasUndoAfterBranch: hasUndoAfterBranch,
        hasRedoAfterBranch: hasRedoAfterBranch,
        afterUndo: afterUndo,
        hasUndoAfterUndo: undoEmpty,
        hasRedoAfterUndo: redoAvailable,
        pointCountAfterUndo: pointCountAfterUndo,
        afterRedo: afterRedo,
        exactAfterRedo: exactAfterRedo,
        pointsAfterRedo: pointsAfterRedo,
    };
})();

const historyDeleteLine = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    const stored = cp.lineMVFB.findExact(line(0, 0, 100, 0, 2));
    const item = new O.HistoryItem();
    item.oldLines.push(stored);
    cp.removeLine(stored);
    const group = new O.HistoryGroup(0);
    group.add(item);
    cp.historyManager.newBranch(group);
    const afterDelete = cp.lineMVFB.size();
    cp.historyManager.undo(cp);
    const afterUndo = cp.lineMVFB.size();
    const pointCountAfterUndo = cp.pointMVFB.size();
    const exactAfterUndo = cp.lineMVFB.findExact(line(0, 0, 100, 0, 2)) === null ? 0 : 1;
    cp.historyManager.redo(cp);
    return {
        afterDelete: afterDelete,
        afterUndo: afterUndo,
        pointCountAfterUndo: pointCountAfterUndo,
        exactAfterUndo: exactAfterUndo,
        afterRedo: cp.lineMVFB.size(),
    };
})();

const historyTypeChange = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    const stored = cp.lineMVFB.findExact(line(0, 0, 100, 0, 2));
    const change = new O.HistoryTypeChange(stored, 2, 3);
    const item = new O.HistoryItem();
    item.changeLines.push(change);
    cp.changeLineType(stored, 3);
    const group = new O.HistoryGroup(0);
    group.add(item);
    cp.historyManager.newBranch(group);
    const typeAfterChange = stored.type();
    cp.historyManager.undo(cp);
    const typeAfterUndo = stored.type();
    cp.historyManager.redo(cp);
    return { typeAfterChange: typeAfterChange, typeAfterUndo: typeAfterUndo, typeAfterRedo: stored.type() };
})();

const historyBranchClearsRedo = (function () {
    const cp = makeTwoLines();
    function branchWithNewLine(x) {
        const added = line(x, 0, x, 100, 3);
        cp.addLineNoCheck(added);
        const group = new O.HistoryGroup(0);
        const item = new O.HistoryItem();
        item.newLines.push(added);
        group.add(item);
        cp.historyManager.newBranch(group);
    }
    branchWithNewLine(0);
    cp.historyManager.undo(cp);
    const redoBefore = cp.historyManager.hasRedo() ? 1 : 0;
    branchWithNewLine(50);
    return {
        redoBeforeNewBranch: redoBefore,
        redoAfterNewBranch: cp.historyManager.hasRedo() ? 1 : 0,
        hasUndo: cp.historyManager.hasUndo() ? 1 : 0,
        lineCount: cp.lineMVFB.size(),
    };
})();

const historyCap = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 100, 0, 2));
    for (let i = 0; i < 60; i++) {
        cp.historyManager.newBranch(new O.HistoryGroup(0));
    }
    let undoCount = 0;
    while (cp.historyManager.hasUndo()) {
        cp.historyManager.undo(cp);
        undoCount++;
        if (undoCount > 100) break;
    }
    cp.historyManager.clearAll();
    return { undoCount: undoCount, hasUndoAfterClear: cp.historyManager.hasUndo() ? 1 : 0 };
})();

const historyMerge = (function () {
    const cp = new O.CreasePattern();
    cp.addLineCheckNoException(line(0, 0, 50, 0, 2));
    cp.addLineCheckNoException(line(50, 0, 100, 0, 2));
    const middle = cp.pointMVFB.findAllPointsInRange(ptd(49, -1), ptd(51, 1)).values()[0];
    const set = new O.JavaSet();
    set.add(middle);
    const items = cp.cleanStraightLines(set);
    const group = new O.HistoryGroup(0);
    group.addAll(items);
    const linesAfterMerge = cp.lineMVFB.size();
    cp.historyManager.newBranch(group);
    cp.historyManager.undo(cp);
    const linesAfterUndo = cp.lineMVFB.size();
    cp.historyManager.redo(cp);
    return { linesAfterMerge: linesAfterMerge, linesAfterUndo: linesAfterUndo, linesAfterRedo: cp.lineMVFB.size() };
})();

const data = {
    defaults: defaults,
    square: square,
    addReject: addReject,
    findQueries: findQueries,
    changeType: changeType,
    removeOrphan: removeOrphan,
    cleanStraight: cleanStraight,
    flatValid: flatValid,
    flatInvalid: flatInvalid,
    clearAll: clearAll,
    history: {
        newLine: historyNewLine,
        deleteLine: historyDeleteLine,
        typeChange: historyTypeChange,
        branchClearsRedo: historyBranchClearsRedo,
        cap: historyCap,
        merge: historyMerge,
    },
};

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "creasepattern.json"), JSON.stringify(data, null, 1) + "\n");
console.log("wrote Fixtures/core/creasepattern.json");

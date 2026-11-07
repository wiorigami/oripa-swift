#!/usr/bin/env node
/*
 * Golden fixture generator for the tree layer (ORIPACore/Tree + CreasePattern line/point
 * trees). Runs the reference JavaScript implementation and dumps expected results to
 * Fixtures/tree/trees.json, which Tests/ORIPATests/CoreTree consumes.
 *
 *   node tools/fixtures/tree/gen_tree.js
 *   ORIPA_JS_ROOT=/path/to/oripa-port/src node tools/fixtures/tree/gen_tree.js
 */
"use strict";
const fs = require("fs");
const path = require("path");
const loadORIPA = require("../load_oripa.js");

const O = loadORIPA();
const OUT = path.resolve(__dirname, "..", "..", "..", "Fixtures", "tree", "trees.json");

function point(x, y) { return new O.OriPoint(x, y); }
function line(a, b, type) { return new O.OriLine(a, b, type === undefined ? 2 : type); }
function lineJson(l) {
    return {
        x1: l.start.x, y1: l.start.y,
        x2: l.end.x, y2: l.end.y,
        type: typeof l.type === "function" ? l.type() : l.type,
    };
}
function sortedLines(values) {
    return values.map((l) => [l.start.x, l.start.y, l.end.x, l.end.y]
        .map((v) => Math.round(v * 1e6) / 1e6))
        .sort((a, b) => {
            for (let i = 0; i < 4; i++) { if (a[i] !== b[i]) return a[i] - b[i]; }
            return 0;
        });
}
function sortedPoints(values) {
    return values.map((p) => [p.x, p.y]).sort((a, b) => (a[0] - b[0]) || (a[1] - b[1]));
}
function inorderNodes(tree) {
    const result = [];
    const it = tree.iterator();
    while (it.hasNext()) result.push(it.next().value);
    return result;
}

/* ---- generic AVL subclass ---- */
function NumberAvlTree() { O.AvlNestedTree.call(this); }
NumberAvlTree.prototype = Object.create(O.AvlNestedTree.prototype);
NumberAvlTree.prototype.constructor = NumberAvlTree;
function NumberAvlNode(value) { O.AvlNode.call(this); this.value = value; this._left = null; this._right = null; }
NumberAvlNode.prototype = Object.create(O.AvlNode.prototype);
NumberAvlNode.prototype.compareTo = function (other) { return this.value - other.value; };
NumberAvlNode.prototype.left = function () { return this._left; };
NumberAvlNode.prototype.right = function () { return this._right; };
NumberAvlNode.prototype.setLeft = function (n) { this._left = n; };
NumberAvlNode.prototype.setRight = function (n) { this._right = n; };
NumberAvlTree.prototype.newNode = function (v) { return new NumberAvlNode(v); };
NumberAvlTree.prototype.insertIntoNested = function () {};
NumberAvlTree.prototype.removeInNested = function () { return false; };
NumberAvlTree.prototype.findExactInNested = function (node, value) { return node.value === value ? node.value : null; };

/* ---- generic red-black subclass ---- */
function NumberRBTree() { O.RedBlackNestedTree.call(this); }
NumberRBTree.prototype = Object.create(O.RedBlackNestedTree.prototype);
NumberRBTree.prototype.constructor = NumberRBTree;
function NumberRBNode(value) {
    this.value = value; this._left = null; this._right = null;
    this._parent = null; this._black = false;
}
NumberRBNode.prototype.compareTo = function (other) { return this.value - other.value; };
NumberRBNode.prototype.left = function () { return this._left; };
NumberRBNode.prototype.right = function () { return this._right; };
NumberRBNode.prototype.parent = function () { return this._parent; };
NumberRBNode.prototype.setLeft = function (n) { this._left = n; };
NumberRBNode.prototype.setRight = function (n) { this._right = n; };
NumberRBNode.prototype.setParent = function (n) { this._parent = n; };
NumberRBNode.prototype.isBlack = function () { return this._black; };
NumberRBNode.prototype.isRed = function () { return !this._black; };
NumberRBNode.prototype.setBlack = function () { this._black = true; };
NumberRBNode.prototype.setRed = function () { this._black = false; };
NumberRBNode.prototype.setIsBlack = function (v) { this._black = v; };
NumberRBTree.prototype.newNode = function (v) { return new NumberRBNode(v); };
NumberRBTree.prototype.insertIntoNested = function () {};
NumberRBTree.prototype.removeInNested = function () { return false; };
NumberRBTree.prototype.updateNode = function () {};

function blackHeight(node) {
    if (!node) return 1;
    const left = blackHeight(node.left());
    const right = blackHeight(node.right());
    if (left === 0 || right === 0 || left !== right) return 0;
    return left + (node.isBlack() ? 1 : 0);
}

const result = {};

/* ---- generic AVL contract ---- */
{
    const tree = new NumberAvlTree();
    for (let i = 1; i <= 100; i++) tree.insert(i);
    const afterInsert = inorderNodes(tree);
    const height = tree.root().height();
    const findExact = [
        { value: 42, expected: tree.findExact(42) },
        { value: 1000, expected: tree.findExact(1000) },
    ];
    for (let i = 1; i <= 100; i += 2) tree.remove(i);
    result.genericAVL = {
        inserts: Array.from({ length: 100 }, (_, i) => i + 1),
        inorderAfterInsert: afterInsert,
        heightAfterInsert: height,
        findExact,
        removes: Array.from({ length: 50 }, (_, i) => i * 2 + 1),
        inorderAfterRemove: inorderNodes(tree),
        isEmptyAfterClear: (tree.clear(), tree.isEmpty()),
    };
}

/* ---- generic red-black contract ---- */
{
    const tree = new NumberRBTree();
    const inserts = Array.from({ length: 300 }, (_, i) => ((i + 1) * 37) % 1000);
    for (const v of inserts) tree.insert(v);
    const afterInsert = inorderNodes(tree);
    const violationAfterInsert = tree.hasViolation();
    const blackHeightAfterInsert = blackHeight(tree.root());
    const removes = Array.from({ length: 100 }, (_, i) => (i * 37) % 1000);
    for (const v of removes) tree.remove(v);
    result.genericRB = {
        inserts,
        inorderAfterInsert: afterInsert,
        violationAfterInsert,
        blackHeightAfterInsert,
        removes,
        inorderAfterRemove: inorderNodes(tree),
        violationAfterRemove: tree.hasViolation(),
        blackHeightAfterRemove: blackHeight(tree.root()),
    };
}

/* ---- point trees (AVL + red-black), 10 x 9 horizontal lines ---- */
function buildPointTree(TreeType) {
    const tree = new TreeType();
    for (let j = 0; j < 10; j++) {
        for (let i = 0; i < 9; i++) {
            tree.addLine(line(point(i * 10, j * 10), point((i + 1) * 10, j * 10)));
        }
    }
    const nearest = tree.findPoint(new O.PointDouble(51, 1), 5);
    const miss = tree.findPoint(new O.PointDouble(5, 5), 1);
    const range = tree.findAllPointsInRange(new O.PointDouble(-1, -1), new O.PointDouble(21, 21));
    const minMax = tree.getMinMax(200);
    const iteration = [];
    for (const p of tree) iteration.push([p.x, p.y]);
    tree.removeLine(line(point(80, 0), point(90, 0)));
    return {
        size: 100,
        containsOrigin: tree.contains(point(0, 0)),
        containsInterior: tree.contains(point(5, 5)),
        nearest: nearest.nearestItem ? [nearest.nearestItem.x, nearest.nearestItem.y] : null,
        nearestDistance: nearest.distance,
        missIsNull: miss.nearestItem === null,
        range: sortedPoints(range.values()),
        minMax: [minMax.minX, minMax.minY, minMax.maxX, minMax.maxY],
        iteration,
        sizeAfterRemoveLine: tree.size(),
        removedPointGone: !tree.contains(point(90, 0)),
        isEmptyAfterClear: (tree.clear(), tree.isEmpty()),
    };
}
result.avlPoint = buildPointTree(O.AvlPointTree);
result.rbPoint = buildPointTree(O.RedBlackPointTree);

/* ---- line trees (AVL + red-black) ---- */
function buildAvlLineTree() {
    const tree = new O.AvlLineTree();
    const lines = [
        line(point(0, 0), point(100, 0)),
        line(point(0, 10), point(100, 10)),
        line(point(0, 20), point(100, 20)),
        line(point(50, -10), point(50, 30)),
        line(point(10, 10), point(90, 10)),
    ];
    for (const l of lines) tree.addLine(l);
    const nearest = tree.findLine(new O.PointDouble(20, 11), 5);
    const range = tree.findAllLinesInRange(new O.PointDouble(40, -5), new O.PointDouble(60, 15));
    const iteration = [];
    for (const l of tree) iteration.push([l.start.x, l.start.y, l.end.x, l.end.y]);
    const containsReversed = tree.contains(line(point(100, 0), point(0, 0)));
    const sizeBeforeRemove = tree.size();
    tree.removeLine(line(point(50, -10), point(50, 30)));
    return {
        lines: lines.map((l) => [l.start.x, l.start.y, l.end.x, l.end.y]),
        size: sizeBeforeRemove,
        containsByValue: tree.contains(line(point(0, 0), point(100, 0))),
        containsReversed,
        nearest: nearest.nearestItem
            ? [nearest.nearestItem.start.y, nearest.nearestItem.end.y]
            : null,
        range: sortedLines(range.values()),
        iteration,
        sizeAfterRemove: tree.size(),
        isEmptyAfterRemove: tree.isEmpty(),
        isEmptyAfterClear: (tree.clear(), tree.isEmpty()),
    };
}
result.avlLine = buildAvlLineTree();

/* ---- red-black line tree with deterministic pseudo-random lines ---- */
{
    const tree = new O.RedBlackLineTree();
    let seed = 7;
    function random(scale) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return ((seed % scale) - (scale / 2)) | 0;
    }
    const lines = [];
    for (let i = 0; i < 120; i++) {
        const x = random(300);
        const y = random(300);
        const x2 = x + random(150);
        const y2 = y + random(150);
        if (x === x2 && y === y2) continue;
        const l = line(point(x, y), point(x2, y2));
        lines.push(l);
        tree.addLine(l);
    }
    const stored = tree.getAllLines().values();
    const nearest = tree.findLine(new O.PointDouble(0, 0), 1000);
    const miss = tree.findLine(new O.PointDouble(-10000, -10000), 1);
    const removeIndices = [];
    for (let i = 0; i < lines.length; i += 3) removeIndices.push(i);
    for (const i of removeIndices) tree.removeLine(lines[i]);
    const iteration = [];
    for (const l of tree) iteration.push(lineJson(l));
    result.rbLine = {
        lines: lines.map((l) => [l.start.x, l.start.y, l.end.x, l.end.y]),
        size: stored.length,
        violation: tree.hasViolation(),
        nearest: nearest.nearestItem ? lineJson(nearest.nearestItem) : null,
        missIsNull: miss.nearestItem === null,
        removeIndices,
        sizeAfterRemove: tree.size(),
        iteration,
    };
}

/* ---- duplicate x/y keys in the nested red-black line tree ---- */
{
    const tree = new O.RedBlackLineTree();
    for (let i = 0; i < 20; i++) {
        tree.addLine(line(point(0, i * 10), point(0, i * 10 + 5)));
    }
    const sizeBefore = tree.size();
    const violationBefore = tree.hasViolation();
    const findExact = tree.findExact(line(point(0, 10), point(0, 15)));
    const range = tree.findAllLinesInRange(new O.PointDouble(-1, 95), new O.PointDouble(1, 125));
    for (let i = 0; i < 20; i += 2) {
        tree.removeLine(line(point(0, i * 10), point(0, i * 10 + 5)));
    }
    result.rbLineDuplicateKeys = {
        sizeBefore,
        violationBefore,
        findExact: findExact ? lineJson(findExact) : null,
        range: sortedLines(range.values()),
        sizeAfterRemove: tree.size(),
        violationAfterRemove: tree.hasViolation(),
    };
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(result));
console.log("wrote " + OUT + " (" + fs.statSync(OUT).size + " bytes)");

#!/usr/bin/env node
/* Golden fixtures for the Java-collection emulation + stacks + HashList/NearestItem
 * (util/JavaCollections.js, HashList.js, FixedStack.js, SimpleStack.js, NearestItem.js). */
"use strict";
const fs = require("fs");
const path = require("path");
const O = require("../load_oripa.js")();
const OUT = path.resolve(__dirname, "../../../Fixtures/core");

function pt(x, y) { return new O.OriPoint(x, y); }
function line(x1, y1, x2, y2, t) { return new O.OriLine(pt(x1, y1), pt(x2, y2), t === undefined ? 2 : t); }
function ptArr(p) { return [p.x, p.y]; }
function lineArr(l) { return [l.start.x, l.start.y, l.end.x, l.end.y, l.type()]; }
function tries(fn) { try { fn(); return 0; } catch (e) { return 1; } }

/* ---- JavaSet (value semantics + JS bucket iteration order) ---- */
const set = new O.JavaSet();
const setAddOrder = [pt(0, 0), pt(10, 0), pt(0, 10), pt(5, 5), pt(-5, 7)];
const addResults = setAddOrder.map(function (p) { return set.add(p) ? 1 : 0; });
const duplicateAdds = [set.add(pt(0, 0)), set.add(pt(5, 5)), set.add(pt(1, 1))].map(function (b) { return b ? 1 : 0; });
const setData = {
    addResults: addResults,
    duplicateAdds: duplicateAdds,
    sizeAfterAdds: set.size(),
    valuesAfterAdds: set.values().map(ptArr),
    contains: [set.contains(pt(0, 0)), set.contains(pt(0, 10)), set.contains(pt(1, 1))].map(function (b) { return b ? 1 : 0; }),
    removeExisting: set.remove(pt(0, 0)) ? 1 : 0,
    removeMissing: set.remove(pt(99, 99)) ? 1 : 0,
    sizeAfterRemove: set.size(),
    valuesAfterRemove: set.values().map(ptArr),
    valuesAfterReAdd: (set.add(pt(0, 0)), set.values().map(ptArr)),
    isEmpty: set.isEmpty() ? 1 : 0,
    afterClear: (set.clear(), { size: set.size(), isEmpty: set.isEmpty() ? 1 : 0, values: set.values() }),
    lineValues: (function () {
        const lineSet = new O.JavaSet();
        lineSet.add(line(0, 0, 10, 0));
        lineSet.add(line(0, 0, 10, 0));
        lineSet.add(line(0, 10, 10, 10));
        lineSet.add(line(10, 0, 0, 0)); // equal to the first (constructor normalizes order)
        return { size: lineSet.size(), values: lineSet.values().map(lineArr) };
    })(),
};

/* ---- JavaLinkedSet (insertion order) ---- */
const linked = new O.JavaLinkedSet();
[pt(0, 0), pt(10, 0), pt(0, 10), pt(5, 5)].forEach(function (p) { linked.add(p); });
linked.add(pt(0, 0));
const linkedData = {
    size: linked.size(),
    values: linked.values().map(ptArr),
    duplicateAdd: linked.add(pt(10, 0)) ? 1 : 0,
    contains: linked.contains(pt(5, 5)) ? 1 : 0,
    removeExisting: linked.remove(pt(10, 0)) ? 1 : 0,
    valuesAfterRemove: linked.values().map(ptArr),
    addAfterRemove: linked.add(pt(10, 0)) ? 1 : 0,
    valuesAfterReAdd: linked.values().map(ptArr),
    afterClear: (linked.clear(), { size: linked.size(), isEmpty: linked.isEmpty() ? 1 : 0 }),
};

/* ---- JavaMap ---- */
const map = new O.JavaMap();
const firstOld = map.put(pt(0, 0), "origin");
map.put(pt(10, 0), "east");
map.put(pt(0, 10), "north");
const overwriteOld = map.put(pt(0, 0), "origin2");
const mapData = {
    firstOld: firstOld,
    overwriteOld: overwriteOld,
    size: map.size(),
    getExisting: map.get(pt(0, 0)),
    getMissing: map.get(pt(7, 7)),
    containsKeys: [map.containsKey(pt(10, 0)), map.containsKey(pt(3, 3))].map(function (b) { return b ? 1 : 0; }),
    keys: map.keySet().map(ptArr),
    values: map.values(),
    entries: map.entries().map(function (e) { return { key: ptArr(e[0]), value: e[1] }; }),
    removeExisting: map.remove(pt(10, 0)),
    removeMissing: map.remove(pt(10, 0)),
    sizeAfterRemove: map.size(),
    valuesAfterRemove: map.values(),
    afterClear: (map.clear(), { size: map.size(), isEmpty: map.isEmpty() ? 1 : 0 }),
};

/* ---- HashList ---- */
const hl = new O.HashList();
const hlLines = [line(30, 0, 40, 0), line(10, 0, 20, 0), line(20, 0, 25, 0), line(50, 0, 60, 0)];
const hlAdds = hlLines.map(function (l) { return hl.add(l) ? 1 : 0; });
const hlDuplicate = hl.add(line(30, 0, 40, 0)) ? 1 : 0;
const hashListData = {
    adds: hlAdds,
    duplicateAdd: hlDuplicate,
    size: hl.size(),
    list: hl.getList().map(lineArr),
    contains: [hl.contains(hlLines[1]), hl.contains(line(0, 0, 1, 0))].map(function (b) { return b ? 1 : 0; }),
    indexes: hlLines.map(function (l) { return hl.getIndex(l); }),
    nextIndexes: hlLines.map(function (l) { return hl.getNextIndex(l); }),
    prevIndexes: hlLines.map(function (l) { return hl.getPrevIndex(l); }),
    getElement: lineArr(hl.getElement(hlLines[2])),
    getNext: hl.getNext(hlLines[0]) === null || hl.getNext(hlLines[0]) === undefined ? null : lineArr(hl.getNext(hlLines[0])),
    getPrev: lineArr(hl.getPrev(hlLines[0])),
    missingThrows: [
        tries(function () { hl.getIndex(line(0, 0, 1, 1)); }),
        tries(function () { hl.getElement(line(0, 0, 1, 1)); }),
        tries(function () { hl.getNextIndex(line(0, 0, 1, 1)); }),
        tries(function () { hl.getPrevIndex(line(0, 0, 1, 1)); }),
        tries(function () { hl.remove(line(0, 0, 1, 1)); }),
    ],
    sorted: (hl.sort(function (a, b) { return a.start.x - b.start.x; }), hl.getList().map(lineArr)),
    removed: (hl.remove(hlLines[1]), hl.getList().map(lineArr)),
    removeLast: (function () { const l = hl.removeLast(); return { removed: lineArr(l), list: hl.getList().map(lineArr) }; })(),
    insertAt: (function () {
        const list = new O.HashList();
        list.add(line(0, 0, 1, 0));
        list.add(line(2, 0, 3, 0));
        list.add(1, line(1, 0, 2, 0));
        return { list: list.getList().map(lineArr), indexOfLast: list.getIndex(line(2, 0, 3, 0)) };
    })(),
};

/* ---- FixedStack(5): bounded, drops oldest ---- */
const fixed = new O.FixedStack(5);
for (let i = 0; i < 8; i++) fixed.push(i);
const fixedIterator = [];
let it = fixed.iterator();
while (it.hasNext()) fixedIterator.push(it.next());
const fixedPops = [];
while (!fixed.isEmpty()) fixedPops.push(fixed.pop());
const fixedData = {
    maxSize: 5,
    iterator: fixedIterator,
    sizeAfterPushes: 5,
    pops: fixedPops,
    emptyAfterDrain: fixed.isEmpty() ? 1 : 0,
    peekThrows: tries(function () { fixed.peek(); }),
    popThrows: tries(function () { fixed.pop(); }),
    withTwo: (function () {
        const stack = new O.FixedStack(2);
        stack.push("a");
        stack.push("b");
        stack.push("c");
        const peaked = stack.peek();
        return { peeked: peaked, pop: stack.pop() };
    })(),
};

/* ---- SimpleStack ---- */
const simple = new O.SimpleStack();
simple.push(1);
simple.push(2);
simple.push(3);
const simpleIterator = [];
it = simple.iterator();
while (it.hasNext()) simpleIterator.push(it.next());
const simpleData = {
    iterator: simpleIterator,
    peek: simple.peek(),
    pops: [simple.pop(), simple.pop(), simple.pop()],
    isEmpty: simple.isEmpty() ? 1 : 0,
    popThrows: tries(function () { simple.pop(); }),
};

/* ---- NearestItem ---- */
const nearestDefault = new O.NearestItem();
const nearestCustom = new O.NearestItem(pt(3, 4), 5.0);
const nearestData = {
    defaultItem: nearestDefault.nearestItem,
    defaultDistance: nearestDefault.distance,
    customItem: ptArr(nearestCustom.nearestItem),
    customDistance: nearestCustom.distance,
};

const data = {
    set: setData,
    linkedSet: linkedData,
    map: mapData,
    hashList: hashListData,
    fixedStack: fixedData,
    simpleStack: simpleData,
    nearestItem: nearestData,
};

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "collections.json"), JSON.stringify(data, null, 1) + "\n");
console.log("wrote Fixtures/core/collections.json");

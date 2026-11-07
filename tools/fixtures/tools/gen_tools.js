#!/usr/bin/env node
/*
 * Golden-fixture generator: ORIPA tool state machines (core-tools workstream).
 *
 * Drives the *reference* JavaScript implementation (oripa-port/src/js) through the exact
 * per-tool event sequences used by oripa-port/tools/tests/test_core_statemachine.js and dumps
 * deterministic expectations to Fixtures/tools/tools.json. The Swift port
 * (Sources/ORIPACore/Model/{StateMachine,Tool}) is verified against this JSON by
 * Tests/ORIPATests/CoreTools; CI never runs Node.
 *
 *   node tools/fixtures/tools/gen_tools.js
 *
 * Env: ORIPA_JS_ROOT=/path/to/oripa-port/src (see tools/fixtures/load_oripa.js).
 *
 * What is recorded per scenario:
 *   - the initial machine flags (tool type / direct-selection / batch capabilities),
 *   - one record per operation: inputs, transition result (0..3) or history-group summary,
 *     the machine's picked-point/line state afterwards, and the crease pattern afterwards
 *     (line/point counts + canonically sorted lines as [x1,y1,x2,y2,type]),
 *   - context mutations for the by-value machines (angle/length setters),
 *   - `getNew()` tool type + flags.
 */
"use strict";
const fs = require("fs");
const path = require("path");
const loadORIPA = require("../load_oripa.js");

const O = loadORIPA();
const R = O.CpTransitionResult;

const OUT_DIR = path.resolve(__dirname, "..", "..", "..", "Fixtures", "tools");
const OUT_FILE = path.join(OUT_DIR, "tools.json");

// ----------------------------------------------------------------------------- helpers
function ptd(x, y) {
    return new O.PointDouble(x, y);
}
function oriPoint(x, y) {
    return new O.OriPoint(x, y);
}
function lineSpec(line) {
    return [line.start.x, line.start.y, line.end.x, line.end.y, line.type()];
}
function cmpNumbers(a, b) {
    for (let i = 0; i < a.length; i++) {
        if (a[i] !== b[i]) return a[i] - b[i];
    }
    return 0;
}
function canonicalLines(cp) {
    const out = [];
    const it = cp.lineMVFB.getAllLines().iterator();
    while (it.hasNext()) out.push(lineSpec(it.next()));
    out.sort(cmpNumbers);
    return out;
}
function canonicalLineSet(set) {
    const out = [];
    const it = set.iterator();
    while (it.hasNext()) out.push(lineSpec(it.next()));
    out.sort(cmpNumbers);
    return out;
}
function pointSpec(p) {
    return [p.x, p.y];
}
function cpSnapshot(cp) {
    return {
        lineCount: cp.lineMVFB.size(),
        pointCount: cp.pointMVFB.size(),
        lines: canonicalLines(cp),
    };
}
function stateSnapshot(sm) {
    const state = sm.getState();
    const points = [];
    const pit = state.pointsPicked.iterator();
    while (pit.hasNext()) points.push(pointSpec(pit.next()));
    return {
        pointsPicked: points,
        linesPicked: canonicalLineSet(state.linesPicked),
        tempPointPicked: state.tempPointPicked === null ? null : pointSpec(state.tempPointPicked),
        tempLinePicked: state.tempLinePicked === null ? null : lineSpec(state.tempLinePicked),
    };
}
function groupSnapshot(group) {
    return { isEmpty: group.isEmpty(), historyItems: group.historyItems.length };
}
function flagsSnapshot(sm) {
    return {
        toolType: sm.getToolType(),
        directSelectionEnabled: sm.getDirectSelectionEnabled(),
        hasBatchLineOperation: sm.hasBatchLineOperation(),
        hasBatchPointOperation: sm.hasBatchPointOperation(),
    };
}

/* Mock of the JS port's state-machine `context` (Android Context/PaintCpFragment slice). */
function makeContext(spec) {
    if (spec === null || spec === undefined) return null;
    const prefs = spec.pref || {};
    const paint = {
        angle: spec.angle === undefined ? 0 : spec.angle,
        length: spec.length === undefined ? 0 : spec.length,
        getByValueButtonAngleDegText: function () { return paint.angle; },
        getByValueButtonLengthText: function () { return paint.length; },
        setByValueButtonAngleDegText: function (value) { paint.angle = value; },
        setByValueButtonLengthText: function (value) { paint.length = value; },
    };
    return {
        paintFragment: paint,
        getPref: function (key, defaultValue) {
            return Object.prototype.hasOwnProperty.call(prefs, key) ? prefs[key] : defaultValue;
        },
        __paint: paint,
    };
}
function contextSnapshot(context) {
    if (context === null || context === undefined) return null;
    return { angle: context.__paint.angle, length: context.__paint.length };
}

// ------------------------------------------------------------------- machine registry
const MACHINES = {
    AddAngleBisectorSM: O.AddAngleBisectorSM,
    AddLineExtensionSM: O.AddLineExtensionSM,
    AddLineSM: O.AddLineSM,
    AddMirroredLinesSM: O.AddMirroredLinesSM,
    AddPerpendicularBisectorSM: O.AddPerpendicularBisectorSM,
    AddPerpendicularSegmentSM: O.AddPerpendicularSegmentSM,
    AddSegmentByValueDrawLineSM: O.AddSegmentByValueDrawLineSM,
    AddSegmentByValueGetAngleSM: O.AddSegmentByValueGetAngleSM,
    AddSegmentByValueGetLengthSM: O.AddSegmentByValueGetLengthSM,
    AddSegmentSM: O.AddSegmentSM,
    AddSymmetricalSegmentSM: O.AddSymmetricalSegmentSM,
    AddTriangleIncenterSM: O.AddTriangleIncenterSM,
    ChangeLineSM: O.ChangeLineSM,
    DeleteLineSM: O.DeleteLineSM,
    DeleteVertexSM: O.DeleteVertexSM,
    SelectLineSM: O.SelectLineSM,
};

const M = O.ChangeLineSM;
const D = O.DeleteLineSM;
const FROM = M.PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM;
const TO = M.PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO;
const DEL = D.PREF_KEY_PAINT_DELETE_LINE_TYPE;

// ------------------------------------------------------------------ scenario builder
function buildScenario(def) {
    const cp = new O.CreasePattern();
    const setup = def.setup || {};
    if (setup.defaultSquare) cp.initializeDefaultSquare();
    for (const line of setup.lines || []) {
        cp.addLineCheckNoException(oriPoint(line[0], line[1]), oriPoint(line[2], line[3]), line[4]);
    }
    const out = {
        name: def.name,
        machine: def.machine,
        manager: def.manager === true,
        directSelection: def.directSelection === true,
        setup: {
            defaultSquare: setup.defaultSquare === true,
            lines: setup.lines || [],
        },
        ops: [],
    };

    let sm;
    if (out.manager) {
        sm = new O.StateMachineManager();
    } else {
        const Ctor = MACHINES[def.machine];
        if (!Ctor) throw new Error("unknown machine " + def.machine);
        sm = new Ctor(out.directSelection);
        out.initial = flagsSnapshot(sm);
    }

    for (const opDef of def.ops) {
        out.ops.push(runOp(sm, cp, opDef));
    }
    out.final = cpSnapshot(cp);
    return out;
}

function currentFlags(sm, manager) {
    return manager ? flagsSnapshot(sm) : flagsSnapshot(sm);
}

function runOp(sm, cp, opDef) {
    const manager = sm instanceof O.StateMachineManager;
    const op = opDef.op;
    const record = { op: op };
    switch (op) {
        case "transition": {
            record.z = opDef.z !== false;
            record.point = opDef.point;
            record.radius = opDef.radius === undefined ? 5 : opDef.radius;
            const result = sm.doTransition(cp, record.z, ptd(opDef.point[0], opDef.point[1]), record.radius);
            record.expect = {
                result: result,
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "longTransition": {
            record.z = opDef.z !== false;
            record.point = opDef.point;
            record.radius = opDef.radius === undefined ? 5 : opDef.radius;
            const result = sm.doLongTransition(cp, record.z, ptd(opDef.point[0], opDef.point[1]), record.radius);
            record.expect = {
                result: result,
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "batchPoint": {
            const context = makeContext(opDef.context);
            record.context = opDef.context === undefined ? null : opDef.context;
            record.start = opDef.start;
            record.end = opDef.end;
            const group = sm.doBatchPointOperation(
                context,
                cp,
                new O.OriPoint(opDef.start[0], opDef.start[1]),
                new O.OriPoint(opDef.end[0], opDef.end[1])
            );
            record.expect = {
                group: groupSnapshot(group),
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "batchLine": {
            const context = makeContext(opDef.context);
            record.context = opDef.context === undefined ? null : opDef.context;
            record.start = opDef.start;
            record.end = opDef.end;
            const group = sm.doBatchLineOperation(
                context,
                cp,
                new O.OriPoint(opDef.start[0], opDef.start[1]),
                new O.OriPoint(opDef.end[0], opDef.end[1])
            );
            record.expect = {
                group: groupSnapshot(group),
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "finish": {
            const context = makeContext(opDef.context);
            record.context = opDef.context === undefined ? null : opDef.context;
            const group = sm.finish(context, cp);
            record.expect = {
                group: groupSnapshot(group),
                context: contextSnapshot(context),
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "selectAll": {
            sm.selectAll(cp);
            record.expect = { state: stateSnapshot(sm) };
            break;
        }
        case "deselectAll": {
            sm.deselectAll();
            record.expect = { state: stateSnapshot(sm) };
            break;
        }
        case "deleteSelected": {
            const group = sm.deleteSelected(cp);
            record.expect = {
                group: groupSnapshot(group),
                state: stateSnapshot(sm),
                cp: cpSnapshot(cp),
            };
            break;
        }
        case "getNew": {
            const fresh = sm.getNew();
            record.expect = flagsSnapshot(fresh);
            break;
        }
        case "newMachine": {
            const Ctor = MACHINES[opDef.machine];
            if (!Ctor) throw new Error("unknown machine " + opDef.machine);
            sm.newMachine(new Ctor(opDef.directSelection === true));
            record.machine = opDef.machine;
            record.directSelection = opDef.directSelection === true;
            record.expect = flagsSnapshot(sm);
            break;
        }
        case "resetMachine": {
            sm.resetMachine();
            record.expect = flagsSnapshot(sm);
            break;
        }
        case "toolType": {
            record.expect = { toolType: sm.getToolType() };
            break;
        }
        default:
            throw new Error("unknown op " + op);
    }
    if (manager) {
        // manager delegation always reports the delegated machine's state/flags
        record.manager = true;
    }
    return record;
}

// ------------------------------------------------------------------ constants
function constants() {
    function sortedIntObject(obj) {
        const out = {};
        for (const key of Object.keys(obj).sort()) out[key] = obj[key];
        return out;
    }
    return {
        toolType: sortedIntObject(O.CpToolType),
        transitionResult: sortedIntObject(O.CpTransitionResult),
        event: sortedIntObject(O.CpEvent),
        changeLineRID: sortedIntObject(O.ChangeLineSM.RID),
        deleteLineRID: sortedIntObject(O.DeleteLineSM.RID),
        changeLinePrefKeys: {
            FROM: O.ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_FROM,
            TO: O.ChangeLineSM.PREF_KEY_PAINT_CHANGE_LINE_TYPE_TO,
        },
        deleteLinePrefKey: O.DeleteLineSM.PREF_KEY_PAINT_DELETE_LINE_TYPE,
    };
}

// ------------------------------------------------------------------ scenario data
const TWO_LINES = [[0, 0, 100, 0, 2], [0, 100, 100, 100, 2]];

const SCENARIOS = [
    // PointsStateMachine family ------------------------------------------------
    {
        name: "AddSegmentSM.direct",
        machine: "AddSegmentSM",
        directSelection: true,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [1, 101] },
            { op: "getNew" },
            { op: "finish", context: null },
            { op: "longTransition", point: [0, 0] },
            { op: "toolType" },
        ],
    },
    {
        name: "AddSegmentSM.indirect",
        machine: "AddSegmentSM",
        directSelection: false,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [500, 500] },
            { op: "transition", point: [99, 99] },
            { op: "transition", point: [99, 99] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddTriangleIncenterSM.direct",
        machine: "AddTriangleIncenterSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2], [0, 0, 0, 100, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "transition", point: [1, 99] },
            { op: "finish", context: null },
            { op: "getNew" },
        ],
    },
    {
        name: "DeleteVertexSM.direct",
        machine: "DeleteVertexSM",
        directSelection: true,
        setup: { lines: [[0, 0, 50, 0, 2], [50, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [51, 1] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "DeleteVertexSM.batch",
        machine: "DeleteVertexSM",
        directSelection: true,
        setup: { lines: [[0, 0, 50, 0, 2], [50, 0, 100, 0, 2]] },
        ops: [
            { op: "batchPoint", start: [-1, -1], end: [51, 1] },
        ],
    },
    {
        name: "AddSegmentByValueGetAngleSM.direct",
        machine: "AddSegmentByValueGetAngleSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 100, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 99] },
            { op: "finish", context: { angle: 123, length: 456 } },
            { op: "getNew" },
        ],
    },
    {
        name: "AddSegmentByValueGetLengthSM.direct",
        machine: "AddSegmentByValueGetLengthSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "finish", context: { angle: 42, length: 999 } },
        ],
    },
    {
        name: "AddSegmentByValueDrawLineSM.direct",
        machine: "AddSegmentByValueDrawLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "finish", context: { angle: 0, length: 10 } },
        ],
    },
    {
        name: "AddSegmentByValueDrawLineSM.angle",
        machine: "AddSegmentByValueDrawLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "finish", context: { angle: 90, length: 10 } },
        ],
    },
    {
        name: "AddSegmentByValueDrawLineSM.noContext",
        machine: "AddSegmentByValueDrawLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "finish", context: null },
        ],
    },

    // PointsAndLinesStateMachine ----------------------------------------------
    {
        name: "AddLineSM.direct",
        machine: "AddLineSM",
        directSelection: true,
        setup: { defaultSquare: true },
        ops: [
            { op: "transition", point: [200, 200] },
            { op: "transition", point: [-200, -200] },
            { op: "transition", point: [0, 200] },
            { op: "transition", point: [0, -200] },
            { op: "finish", context: null },
            { op: "getNew" },
        ],
    },
    {
        name: "AddLineSM.indirect",
        machine: "AddLineSM",
        directSelection: false,
        setup: { defaultSquare: true },
        ops: [
            { op: "transition", point: [200, 200] },
            { op: "transition", point: [200, 200] },
            { op: "transition", point: [-200, -200] },
            { op: "transition", point: [-200, -200] },
            { op: "transition", point: [0, 200] },
            { op: "transition", point: [0, -200] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddPerpendicularBisectorSM.direct",
        machine: "AddPerpendicularBisectorSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2], [0, 50, 100, 50, 2], [0, -100, 100, -100, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "transition", point: [50, 50] },
            { op: "transition", point: [50, -100] },
            { op: "finish", context: null },
        ],
    },

    // PointsAndLineStateMachine -----------------------------------------------
    {
        name: "AddPerpendicularSegmentSM.direct",
        machine: "AddPerpendicularSegmentSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2], [50, 10, 60, 10, 2]] },
        ops: [
            { op: "transition", point: [50, 10] },
            { op: "transition", point: [20, 1] },
            { op: "finish", context: null },
            { op: "getNew" },
        ],
    },
    {
        name: "AddPerpendicularSegmentSM.indirect",
        machine: "AddPerpendicularSegmentSM",
        directSelection: false,
        setup: { lines: [[0, 0, 100, 0, 2], [50, 10, 60, 10, 2]] },
        ops: [
            { op: "transition", point: [50, 10] },
            { op: "transition", point: [50, 10] },
            { op: "transition", point: [20, 1] },
            { op: "transition", point: [20, 1] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddAngleBisectorSM.direct",
        machine: "AddAngleBisectorSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2], [0, 0, 0, 100, 2], [50, 50, 100, 50, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "transition", point: [1, 99] },
            { op: "transition", point: [75, 50] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddLineExtensionSM.direct",
        machine: "AddLineExtensionSM",
        directSelection: true,
        setup: { lines: [[0, 0, 0, 10, 2], [100, 0, 100, 10, 2], [150, -10, 150, 10, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "transition", point: [150, 1] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddLineExtensionSM.rejectParallel",
        machine: "AddLineExtensionSM",
        directSelection: true,
        setup: { lines: [[0, 0, 0, 10, 2], [100, 0, 100, 10, 2], [0, 10, 200, 10, 2]] },
        ops: [
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [99, 1] },
            { op: "transition", point: [150, 10] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddSymmetricalSegmentSM.direct",
        machine: "AddSymmetricalSegmentSM",
        directSelection: true,
        setup: { lines: [[50, 0, 50, 50, 2], [0, 0, 0, 100, 2], [-25, -100, -25, 100, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "transition", point: [1, 1] },
            { op: "transition", point: [1, 99] },
            { op: "transition", point: [-25, 1] },
            { op: "finish", context: null },
        ],
    },

    // LineStateMachine family --------------------------------------------------
    {
        name: "DeleteLineSM.direct",
        machine: "DeleteLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "DeleteLineSM.indirect",
        machine: "DeleteLineSM",
        directSelection: false,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "transition", point: [50, 1] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "DeleteLineSM.filterFlat",
        machine: "DeleteLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "finish", context: { pref: { [DEL]: D.RID.FLAT } } },
        ],
    },
    {
        name: "DeleteLineSM.batchAny",
        machine: "DeleteLineSM",
        directSelection: true,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "batchLine", start: [-1, -1], end: [101, 101] },
        ],
    },
    {
        name: "ChangeLineSM.flipToValley",
        machine: "ChangeLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "finish", context: { pref: { [TO]: M.RID.TO_FLIP } } },
            { op: "getNew" },
        ],
    },
    {
        name: "ChangeLineSM.batchToMountain",
        machine: "ChangeLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 3]] },
        ops: [
            { op: "batchLine", start: [-1, -1], end: [101, 1] },
        ],
    },
    {
        name: "ChangeLineSM.fromBoundaryNoChange",
        machine: "ChangeLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "batchLine", start: [-1, -1], end: [101, 1], context: { pref: { [FROM]: M.RID.FROM_BOUNDARY } } },
        ],
    },
    {
        name: "ChangeLineSM.toSameTypeNoChange",
        machine: "ChangeLineSM",
        directSelection: true,
        setup: { lines: [[0, 0, 100, 0, 2]] },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "finish", context: { pref: { [TO]: M.RID.TO_MOUNTAIN } } },
        ],
    },

    // LinesToggleStateMachine --------------------------------------------------
    {
        name: "SelectLineSM.toggleSelectDelete",
        machine: "SelectLineSM",
        directSelection: true,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "transition", point: [50, 1] },
            { op: "transition", point: [50, 1] },
            { op: "selectAll" },
            { op: "deleteSelected" },
            { op: "deselectAll" },
            { op: "finish", context: null },
            { op: "getNew" },
        ],
    },
    {
        name: "SelectLineSM.batch",
        machine: "SelectLineSM",
        directSelection: true,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "batchLine", start: [-1, -1], end: [101, 101] },
            { op: "finish", context: null },
        ],
    },
    {
        name: "AddMirroredLinesSM.direct",
        machine: "AddMirroredLinesSM",
        directSelection: true,
        setup: { lines: [[0, 10, 50, 10, 2], [0, 0, 0, 100, 1]] },
        ops: [
            { op: "transition", point: [25, 10] },
            { op: "longTransition", point: [0.5, 50] },
            { op: "finish", context: null },
            { op: "getNew" },
        ],
    },
    {
        name: "AddMirroredLinesSM.batch",
        machine: "AddMirroredLinesSM",
        directSelection: true,
        setup: { lines: [[0, 10, 50, 10, 2]] },
        ops: [
            { op: "batchLine", start: [-1, 9], end: [51, 11] },
        ],
    },

    // StateMachineManager ------------------------------------------------------
    {
        name: "StateMachineManager.delegation",
        machine: "StateMachineManager",
        manager: true,
        setup: { lines: TWO_LINES },
        ops: [
            { op: "newMachine", machine: "AddSegmentSM", directSelection: true },
            { op: "transition", point: [1, 1] },
            { op: "longTransition", point: [1, 1] },
            { op: "toolType" },
            { op: "resetMachine" },
            { op: "newMachine", machine: "SelectLineSM", directSelection: true },
            { op: "batchLine", start: [-1, -1], end: [101, 101] },
            { op: "finish", context: null },
            { op: "newMachine", machine: "DeleteLineSM", directSelection: true },
            { op: "batchLine", start: [-1, -1], end: [101, 101], context: { pref: { [DEL]: D.RID.MOUNTAIN } } },
        ],
    },
];

// ----------------------------------------------------------------------------- main
function main() {
    const fixture = {
        meta: {
            source: "oripa-port/src/js/core/model/{statemachine,tool}",
            generator: "tools/fixtures/tools/gen_tools.js",
            referenceSuite: "oripa-port/tools/tests/test_core_statemachine.js",
            transitionResults: { CHANGED_POINTS: R.CHANGED_POINTS, CHANGED_LINES: R.CHANGED_LINES, NO_CHANGE: R.NO_CHANGE, FINISHED: R.FINISHED },
        },
        constants: constants(),
        scenarios: SCENARIOS.map(buildScenario),
    };
    fs.mkdirSync(OUT_DIR, { recursive: true });
    fs.writeFileSync(OUT_FILE, JSON.stringify(fixture, null, 2) + "\n", "utf8");

    let opCount = 0;
    for (const scenario of fixture.scenarios) opCount += scenario.ops.length;
    console.log(
        "wrote " + path.relative(process.cwd(), OUT_FILE) +
        ": " + fixture.scenarios.length + " scenarios, " + opCount + " ops, " +
        Object.keys(fixture.constants.toolType).length + " tool types"
    );
}

main();

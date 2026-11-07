#!/usr/bin/env node
/* Golden fixtures for ORIPA resources (resource/*.js): LineType/GridType/FileType/
 * ProjectKey/ProjectValue/RenderKey/Color/Constant.
 * Emits Fixtures/core/resources.json (consumed by Tests/ORIPATests/CoreModel). */
"use strict";
const fs = require("fs");
const path = require("path");
const O = require("../load_oripa.js")();

const OUT = path.resolve(__dirname, "../../../Fixtures/core");
const f32 = Math.fround;
const lineTypes = [0, 1, 2, 3, 4, 5, 6, 7, 127];

const colorNames = [
    "COLOR_BOUNDARY", "COLOR_VALLEY", "COLOR_MOUNTAIN", "COLOR_FLAT", "COLOR_GRID",
    "COLOR_SLICE", "COLOR_PICKED", "COLOR_ERROR", "COLOR_CP_POLYGON_FILL",
    "COLOR_TOUCH_CIRCLE", "COLOR_SELECTION_RECT", "COLOR_XRAY_FACE", "COLOR_XRAY_CREASE",
    "COLOR_XRAY_BOUNDARY", "COLOR_WIRE_CREASE", "COLOR_WIRE_BOUNDARY",
];


const renderKeyNames = Object.keys(O.RenderKey).filter(function (key) {
    return key !== "key";
});
const renderKeys = {};
for (const name of renderKeyNames) renderKeys[name] = O.RenderKey[name];

const data = {
    lineTypes: {
        values: lineTypes,
        strings: lineTypes.map(function (b) { return O.LineType.getString(b); }),
        abbreviations: lineTypes.map(function (b) { return O.LineType.getAbbreviation(b); }),
        colors: lineTypes.map(function (b) {
            const color = O.LineType.getColor(b);
            return color ? [f32(color[0]), f32(color[1]), f32(color[2])] : null;
        }),
    },
    gridTypes: {
        SQUARE: O.GridType.SQUARE,
        TRIANGLE: O.GridType.TRIANGLE,
        UNDEFINED: O.GridType.UNDEFINED,
    },
    fileTypes: O.FileType.values().map(function (f) {
        return {
            name: f.name(),
            ordinal: f.ordinal(),
            extension: f.getExtension(),
            mime: f.getMimeType(),
            valueOfKnowsName: O.FileType.valueOf(f.name()) === f,
        };
    }),
    projectKeys: O.ProjectKey.values().map(function (k) {
        return { name: k.name(), ordinal: k.ordinal(), key: k.getKey() };
    }),
    renderKeys: renderKeys,
    renderKeyExamples: [
        "X",
        "CP_LINE_POSITION",
        "BUNDLE_FOLD_OVERLAP_SPLIT_%d",
    ].map(function (s) { return [s, O.RenderKey.key(s)]; }),
    constants: Object.keys(O.Constant).reduce(function (acc, key) {
        acc[key] = f32(O.Constant[key]);
        return acc;
    }, {}),
    colorConstants: colorNames.reduce(function (acc, name) {
        acc[name] = O.Color[name].map(function (v) { return f32(v); });
        return acc;
    }, {}),
    projectValues: {
        KEY_DIALOG: O.ProjectValue.KEY_DIALOG,
        PROJECT_SUBDIRECTORY: O.ProjectValue.PROJECT_SUBDIRECTORY,
        REQUEST_CODE_PREVIEW: O.ProjectValue.REQUEST_CODE_PREVIEW,
        RESULT_CODE_COPY: O.ProjectValue.RESULT_CODE_COPY,
        RESULT_CODE_DELETE: O.ProjectValue.RESULT_CODE_DELETE,
        RESULT_CODE_NO_CHANGE: O.ProjectValue.RESULT_CODE_NO_CHANGE,
        RESULT_CODE_RENAME: O.ProjectValue.RESULT_CODE_RENAME,
        THUMBNAIL_SUBDIRECTORY: O.ProjectValue.THUMBNAIL_SUBDIRECTORY,
        projectDirNoBase: O.ProjectValue.getProjectDirectory(),
        projectDirBase: O.ProjectValue.getProjectDirectory("/base"),
        tempNoBase: O.ProjectValue.getTempSaveFile(),
        tempBase: O.ProjectValue.getTempSaveFile("/base"),
        thumbNoBase: O.ProjectValue.getThumbDirectory(),
        thumbBase: O.ProjectValue.getThumbDirectory("/base"),
    },
};

fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "resources.json"), JSON.stringify(data, null, 1) + "\n");
console.log("wrote Fixtures/core/resources.json");

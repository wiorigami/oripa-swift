#!/usr/bin/env node
/*
 * Loader for the reference ORIPA JavaScript implementation (oripa-port/src/js).
 *
 * Golden-fixture generators under tools/fixtures/<area>/ use this to execute the
 * reference implementation in Node, then dump expected values to JSON. The committed
 * JSON is what the Swift tests (and CI) consume — CI never runs Node.
 *
 *   const O = require("../load_oripa.js")();            // auto-detect ../oripa-port
 *   const O = require("../load_oripa.js")({ src: "/path/to/oripa-port/src" });
 *
 * Env override: ORIPA_JS_ROOT=/path/to/oripa-port/src
 *
 * The loader evaluates platform.js + core/render files in the same order as the web
 * build (see oripa-port/tools/load_node.js), in a fake-browser global. UI files are not
 * loaded (they require a DOM). `O.<Class>` is the flat ORIPA namespace.
 */
"use strict";
const fs = require("fs");
const path = require("path");

const REPO_ROOT = path.resolve(__dirname, "..", "..");

function detectSource(opts) {
    const candidates = [];
    if (opts && opts.src) candidates.push(opts.src);
    if (process.env.ORIPA_JS_ROOT) candidates.push(process.env.ORIPA_JS_ROOT);
    candidates.push(path.resolve(REPO_ROOT, "..", "oripa-port", "src"));
    candidates.push(path.resolve(REPO_ROOT, "oripa-port", "src"));
    for (const c of candidates) {
        if (c && fs.existsSync(path.join(c, "js", "platform.js"))) return c;
    }
    throw new Error(
        "oripa-port JS sources not found. Pass {src: '.../oripa-port/src'} or set ORIPA_JS_ROOT."
    );
}

function collect(src) {
    const order = [
        "js/platform.js",
        "js/core/resource",
        "js/core/tree",
        "js/core/util",
        "js/core/model/creasepattern",
        "js/core/model/history",
        "js/core/model/statemachine",
        "js/core/model/tool",
        "js/core/model/foldedmodel",
        "js/core/model/renderdata",
        "js/core/io",
        "js/core/io/load",
        "js/core/io/export",
        "js/render",
    ];
    const files = [];
    const seen = new Set();
    const add = (p) => {
        if (fs.existsSync(p) && !seen.has(p)) { seen.add(p); files.push(p); }
    };
    for (const entry of order) {
        const full = path.join(src, entry);
        if (entry.endsWith(".js")) { add(full); continue; }
        if (!fs.existsSync(full)) continue;
        const walk = (dir) => {
            for (const name of fs.readdirSync(dir).sort()) {
                const p = path.join(dir, name);
                if (fs.statSync(p).isDirectory()) walk(p);
                else if (name.endsWith(".js")) add(p);
            }
        };
        walk(full);
    }
    return files;
}

function makeStorage() {
    const mem = new Map();
    return {
        getItem: (k) => (mem.has(k) ? mem.get(k) : null),
        setItem: (k, v) => mem.set(k, String(v)),
        removeItem: (k) => mem.delete(k),
        key: (i) => Array.from(mem.keys())[i] || null,
        get length() { return mem.size; },
    };
}

function installFakeBrowser() {
    if (global.window && global.window.ORIPA) return;
    global.window = global;
    global.localStorage = makeStorage();
    try {
        Object.defineProperty(global, "navigator", {
            value: global.navigator || { userAgent: "node" },
            configurable: true,
            writable: true,
        });
    } catch (e) { /* Node exposes navigator as a getter */ }
    if (typeof global.atob !== "function") {
        global.atob = (b64) => Buffer.from(b64, "base64").toString("binary");
        global.btoa = (bin) => Buffer.from(bin, "binary").toString("base64");
    }
    if (typeof global.TextEncoder === "undefined") {
        const { TextEncoder, TextDecoder } = require("util");
        global.TextEncoder = TextEncoder;
        global.TextDecoder = TextDecoder;
    }
}

module.exports = function loadORIPA(opts) {
    installFakeBrowser();
    const src = detectSource(opts || {});
    global.ORIPA = global.ORIPA || {};
    for (const file of collect(src)) {
        const code = fs.readFileSync(file, "utf8");
        try {
            // eslint-disable-next-line no-new-func
            new Function("window", "localStorage", "document", "navigator", code)(
                global, global.localStorage, global.document, global.navigator
            );
        } catch (e) {
            console.error("load failed:", path.relative(src, file));
            throw e;
        }
    }
    return global.window.ORIPA;
};
